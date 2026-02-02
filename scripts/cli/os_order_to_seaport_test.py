import argparse
import json
import os
import time
import urllib.error
import urllib.request
from urllib.parse import urlencode


def to_uint(value):
    if isinstance(value, str):
        if value.startswith("0x"):
            return int(value, 16)
        return int(value)
    return value


def addr_literal(value):
    if not isinstance(value, str):
        raise ValueError("address must be a string")
    hex_value = value[2:] if value.startswith("0x") else value
    return "address(uint160(uint256(0x00{})))".format(hex_value.lower())


def bytes_literal(value):
    if not value:
        return 'hex""'
    hex_value = (
        value[2:] if isinstance(value, str) and value.startswith("0x") else value
    )
    return 'hex"{}"'.format(str(hex_value).lower())


def bytes32_literal(value):
    if not value:
        return "bytes32(0)"
    hex_value = (
        value[2:] if isinstance(value, str) and value.startswith("0x") else value
    )
    return "bytes32(0x{})".format(str(hex_value).lower())


def to_side(value):
    if isinstance(value, str):
        lowered = value.lower()
        if lowered == "offer":
            return 0
        if lowered == "consideration":
            return 1
    return to_uint(value)


def fetch_json(url, headers, payload=None, retries=3, backoff=1.5) -> dict:
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers, data=data)
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as err:
            body = err.read().decode("utf-8", "replace")
            if 500 <= err.code < 600 and attempt < retries:
                time.sleep(backoff * attempt)
                continue
            raise SystemExit(f"HTTP {err.code} from {url}: {body[:500]}")
        except urllib.error.URLError as err:
            if attempt < retries:
                time.sleep(backoff * attempt)
                continue
            raise SystemExit(f"Network error from {url}: {err}")
    raise SystemExit(f"Failed to fetch {url} after {retries} attempts")


def fmt_offer(item):
    return "ISeaport.OfferItem(ISeaport.ItemType({}), {}, {}, {}, {})".format(
        to_uint(item["itemType"]),
        addr_literal(item["token"]),
        to_uint(item["identifierOrCriteria"]),
        to_uint(item["startAmount"]),
        to_uint(item["endAmount"]),
    )


def fmt_consideration(item):
    return (
        "ISeaport.ConsiderationItem(ISeaport.ItemType({}), {}, {}, {}, {}, {})".format(
            to_uint(item["itemType"]),
            addr_literal(item["token"]),
            to_uint(item["identifierOrCriteria"]),
            to_uint(item["startAmount"]),
            to_uint(item["endAmount"]),
            addr_literal(item["recipient"]),
        )
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate a Seaport fork test from an OpenSea listing"
    )
    parser.add_argument("--contract", required=True, help="ERC721 contract address")
    parser.add_argument("--token-id", required=True, help="Token identifier")
    parser.add_argument(
        "--api-key",
        default=os.environ.get("OPENSEA_API_KEY", ""),
        help="OpenSea API key (or OPENSEA_API_KEY env)",
    )
    parser.add_argument(
        "--chain",
        default="ethereum",
        help="OpenSea chain name (default: ethereum)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=1,
        help="Max listings to fetch (default: 1)",
    )
    parser.add_argument(
        "--order-index",
        type=int,
        default=0,
        help="Index into returned listings (default: 0)",
    )
    parser.add_argument(
        "--out",
        default="forge-tests/SeaportOrderDebug.t.sol",
        help="Output Solidity test path",
    )
    parser.add_argument(
        "--buyer",
        default="0x000000000000000000000000000000000000BEEF",
        help="Recipient address for the NFT",
    )
    parser.add_argument(
        "--as-buyer",
        action="store_true",
        help="Call as buyer (requires signature)",
    )
    parser.add_argument(
        "--signature",
        default="",
        help="Optional signature override (0x...)",
    )
    parser.add_argument(
        "--fulfillment-json",
        default="",
        help="Path to OpenSea fulfillment_data JSON (optional)",
    )
    parser.add_argument(
        "--use-fulfillment-data",
        action="store_true",
        help="Generate test from OpenSea fulfillment_data transaction",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if not args.api_key:
        raise SystemExit("Missing API key: use --api-key or OPENSEA_API_KEY")

    query = urlencode(
        {
            "asset_contract_address": args.contract,
            "token_ids": args.token_id,
            "limit": str(args.limit),
        }
    )
    url = f"https://api.opensea.io/api/v2/orders/{args.chain}/seaport/listings?{query}"
    headers = {
        "X-API-KEY": args.api_key,
        "accept": "application/json",
        "user-agent": "Mozilla/5.0",
    }

    data = fetch_json(url, headers)

    orders = data.get("orders", [])
    if not orders:
        raise SystemExit("No orders found for given contract/token")
    if args.order_index < 0 or args.order_index >= len(orders):
        raise SystemExit("order-index out of range")

    order = orders[args.order_index]
    protocol_data = order.get("protocol_data", {})
    params = protocol_data.get("parameters", {})
    if not params:
        raise SystemExit("Missing protocol_data.parameters in order")

    signature = args.signature or (protocol_data.get("signature") or "")
    if args.as_buyer and not signature:
        raise SystemExit("--as-buyer requires a signature")

    order_hash = order.get("order_hash")
    protocol_address = order.get("protocol_address")

    if args.use_fulfillment_data:
        fulfillment_url = "https://api.opensea.io/api/v2/listings/fulfillment_data"
        fulfillment = None
        if args.fulfillment_json:
            with open(args.fulfillment_json, "r", encoding="utf-8") as handle:
                fulfillment = json.load(handle)
        else:
            chain_variants = {args.chain, args.chain.lower(), args.chain.upper()}
            protocol_variants = {protocol_address, protocol_address.lower()}
            buyer_variants = {args.buyer, args.buyer.lower()}

            payloads = []
            for chain in chain_variants:
                for protocol in protocol_variants:
                    for buyer in buyer_variants:
                        payloads.append(
                            {
                                "listing": {
                                    "hash": order_hash,
                                    "protocol_address": protocol,
                                    "chain": chain,
                                },
                                "fulfiller": {"address": buyer},
                            }
                        )
                        payloads.append(
                            {
                                "listing": {
                                    "hash": order_hash,
                                    "protocol_address": protocol,
                                    "chain": chain,
                                    "protocol": "seaport",
                                },
                                "fulfiller": {"address": buyer},
                            }
                        )

            errors = []
            for payload in payloads:
                try:
                    fulfillment = fetch_json(fulfillment_url, headers, payload)
                except SystemExit as exc:
                    errors.append(str(exc))
                    continue

                tx = fulfillment.get("fulfillment_data", {}).get("transaction")
                if tx:
                    break
                errors.append("Missing fulfillment_data.transaction")
                fulfillment = None

            if not fulfillment:
                detail = "; ".join(errors[-3:]) if errors else "unknown error"
                raise SystemExit(f"Unable to fetch fulfillment_data. {detail}")

        tx = fulfillment.get("fulfillment_data", {}).get(
            "transaction"
        ) or fulfillment.get("transaction", {})
        if not tx:
            raise SystemExit("Missing fulfillment_data.transaction in response")

        tx_to = tx.get("to")
        tx_value = to_uint(tx.get("value", 0))
        tx_input = tx.get("input_data", "")
        if not tx_to or tx_input is None:
            raise SystemExit("Missing to/input_data in fulfillment transaction")

        if isinstance(tx_input, dict):
            advanced = tx_input.get("advancedOrder", {})
            criteria = tx_input.get("criteriaResolvers", [])
            fulfiller_conduit_key = tx_input.get("fulfillerConduitKey", "")
            recipient = tx_input.get("recipient") or args.buyer

            adv_params = advanced.get("parameters", {})
            if not adv_params:
                raise SystemExit(
                    "Missing advancedOrder.parameters in fulfillment input_data"
                )

            offer_items = [fmt_offer(it) for it in adv_params.get("offer", [])]
            cons_items = [
                fmt_consideration(it) for it in adv_params.get("consideration", [])
            ]
            adv_signature = advanced.get("signature", "")
            adv_extra = advanced.get("extraData", "")
            numerator = to_uint(advanced.get("numerator", 1))
            denominator = to_uint(advanced.get("denominator", 1))

            lines = []
            lines.append("// SPDX-License-Identifier: MIT")
            lines.append("pragma solidity ^0.8.23;")
            lines.append("")
            lines.append('import "forge-std/Test.sol";')
            lines.append("")
            lines.append("interface IERC20 {")
            lines.append(
                "    function approve(address spender, uint256 amount) external returns (bool);"
            )
            lines.append("}")
            lines.append("")
            lines.append("interface ISeaport {")
            lines.append(
                "    enum ItemType { NATIVE, ERC20, ERC721, ERC1155, ERC721_WITH_CRITERIA, ERC1155_WITH_CRITERIA }"
            )
            lines.append("    enum Side { OFFER, CONSIDERATION }")
            lines.append(
                "    struct OfferItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; }"
            )
            lines.append(
                "    struct ConsiderationItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; address recipient; }"
            )
            lines.append(
                "    struct OrderParameters { address offerer; address zone; OfferItem[] offer; ConsiderationItem[] consideration; uint8 orderType; uint256 startTime; uint256 endTime; bytes32 zoneHash; uint256 salt; bytes32 conduitKey; uint256 totalOriginalConsiderationItems; }"
            )
            lines.append(
                "    struct Order { OrderParameters parameters; bytes signature; }"
            )
            lines.append(
                "    struct AdvancedOrder { OrderParameters parameters; uint120 numerator; uint120 denominator; bytes signature; bytes extraData; }"
            )
            lines.append(
                "    struct CriteriaResolver { uint256 orderIndex; Side side; uint256 index; uint256 identifier; bytes32[] criteriaProof; }"
            )
            lines.append(
                "    function fulfillAdvancedOrder(AdvancedOrder calldata advancedOrder, CriteriaResolver[] calldata criteriaResolvers, bytes32 fulfillerConduitKey, address recipient) external payable returns (bool fulfilled);"
            )
            lines.append("}")
            lines.append("")
            lines.append("contract SeaportOrderDebug is Test {")
            lines.append(f"    address constant SEAPORT = {addr_literal(tx_to)};")
            lines.append(f"    uint256 constant CALL_VALUE = {tx_value};")
            lines.append("")
            lines.append("    function test_fulfillViaFulfillmentData() public {")
            lines.append("        ISeaport seaport = ISeaport(SEAPORT);")
            lines.append("")
            lines.append(
                f"        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[]({len(offer_items)});"
            )
            for i, item in enumerate(offer_items):
                lines.append(f"        offer[{i}] = {item};")
            lines.append("")
            lines.append(
                f"        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[]({len(cons_items)});"
            )
            for i, item in enumerate(cons_items):
                lines.append(f"        consideration[{i}] = {item};")
            lines.append("")
            lines.append(
                "        ISeaport.OrderParameters memory p = ISeaport.OrderParameters({"
            )
            lines.append(
                f"            offerer: {addr_literal(adv_params.get('offerer'))},"
            )
            lines.append(f"            zone: {addr_literal(adv_params.get('zone'))},")
            lines.append("            offer: offer,")
            lines.append("            consideration: consideration,")
            lines.append(
                f"            orderType: {to_uint(adv_params.get('orderType', 0))},"
            )
            lines.append(
                f"            startTime: {to_uint(adv_params.get('startTime', 0))},"
            )
            lines.append(
                f"            endTime: {to_uint(adv_params.get('endTime', 0))},"
            )
            lines.append(
                f"            zoneHash: {bytes32_literal(adv_params.get('zoneHash'))},"
            )
            lines.append(f"            salt: {to_uint(adv_params.get('salt', 0))},")
            lines.append(
                f"            conduitKey: {bytes32_literal(adv_params.get('conduitKey'))},"
            )
            lines.append(
                f"            totalOriginalConsiderationItems: {to_uint(adv_params.get('totalOriginalConsiderationItems', len(cons_items)))}"
            )
            lines.append("        });")
            lines.append("")
            lines.append(
                "        ISeaport.AdvancedOrder memory order = ISeaport.AdvancedOrder({"
            )
            lines.append("            parameters: p,")
            lines.append(f"            numerator: {numerator},")
            lines.append(f"            denominator: {denominator},")
            lines.append(f"            signature: {bytes_literal(adv_signature)},")
            lines.append(f"            extraData: {bytes_literal(adv_extra)}")
            lines.append("        });")
            lines.append("")
            lines.append(
                f"        ISeaport.CriteriaResolver[] memory criteriaResolvers = new ISeaport.CriteriaResolver[]({len(criteria)});"
            )
            for i, resolver in enumerate(criteria):
                proof = resolver.get("criteriaProof") or []
                lines.append(
                    f"        bytes32[] memory proof{i} = new bytes32[]({len(proof)});"
                )
                for j, entry in enumerate(proof):
                    lines.append(f"        proof{i}[{j}] = {bytes32_literal(entry)};")
                lines.append(
                    "        criteriaResolvers[{}] = ISeaport.CriteriaResolver({{ orderIndex: {}, side: ISeaport.Side({}), index: {}, identifier: {}, criteriaProof: proof{} }});".format(
                        i,
                        to_uint(resolver.get("orderIndex", 0)),
                        to_side(resolver.get("side", 0)),
                        to_uint(resolver.get("index", 0)),
                        to_uint(resolver.get("identifier", 0)),
                        i,
                    )
                )
            lines.append("")
            lines.append(
                f"        bytes32 fulfillerConduitKey = {bytes32_literal(fulfiller_conduit_key)};"
            )
            lines.append(f"        address recipient = {addr_literal(recipient)};")
            lines.append(f"        address buyer = {addr_literal(args.buyer)};")
            lines.append("        if (CALL_VALUE > 0) { vm.deal(buyer, CALL_VALUE); }")
            lines.append("        vm.prank(buyer);")
            lines.append(
                "        bool ok = seaport.fulfillAdvancedOrder{ value: CALL_VALUE }(order, criteriaResolvers, fulfillerConduitKey, recipient);"
            )
            lines.append(
                '        console2.log("fulfilled", ok ? uint256(1) : uint256(0));'
            )
            lines.append("    }")
            lines.append("}")

            with open(args.out, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))

            print("wrote", args.out)
            print("order_hash", order_hash)
            print("protocol", protocol_address)
            return

        if isinstance(tx_input, str):
            tx_input_hex = tx_input[2:] if tx_input.startswith("0x") else tx_input
            if not tx_input_hex:
                raise SystemExit("Missing input_data in fulfillment transaction")

            lines = []
            lines.append("// SPDX-License-Identifier: MIT")
            lines.append("pragma solidity ^0.8.23;")
            lines.append("")
            lines.append('import "forge-std/Test.sol";')
            lines.append("")
            lines.append("contract SeaportOrderDebug is Test {")
            lines.append(f"    address constant TARGET = {addr_literal(tx_to)};")
            lines.append(f"    uint256 constant CALL_VALUE = {tx_value};")
            lines.append(f'    bytes constant CALLDATA = hex"{tx_input_hex}";')
            lines.append("")
            lines.append("    function test_fulfillViaFulfillmentData() public {")
            lines.append(f"        address buyer = {addr_literal(args.buyer)};")
            lines.append("        if (CALL_VALUE > 0) { vm.deal(buyer, CALL_VALUE); }")
            lines.append("        vm.prank(buyer);")
            lines.append(
                "        (bool ok, bytes memory data) = TARGET.call{ value: CALL_VALUE }(CALLDATA);"
            )
            lines.append("        if (!ok) {")
            lines.append("            assembly {")
            lines.append("                revert(add(data, 32), mload(data))")
            lines.append("            }")
            lines.append("        }")
            lines.append("    }")
            lines.append("}")

            with open(args.out, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))

            print("wrote", args.out)
            print("order_hash", order_hash)
            print("protocol", protocol_address)
            return

        raise SystemExit("Unsupported input_data type in fulfillment transaction")

    offer_items = [fmt_offer(it) for it in params["offer"]]
    cons_items = [fmt_consideration(it) for it in params["consideration"]]

    sig = signature[2:] if signature.startswith("0x") else signature

    lines = []
    lines.append("// SPDX-License-Identifier: MIT")
    lines.append("pragma solidity ^0.8.23;")
    lines.append("")
    lines.append('import "forge-std/Test.sol";')
    lines.append("")
    lines.append("interface IERC20 {")
    lines.append(
        "    function approve(address spender, uint256 amount) external returns (bool);"
    )
    lines.append("}")
    lines.append("")
    lines.append("interface ISeaport {")
    lines.append(
        "    enum ItemType { NATIVE, ERC20, ERC721, ERC1155, ERC721_WITH_CRITERIA, ERC1155_WITH_CRITERIA }"
    )
    lines.append("    enum Side { OFFER, CONSIDERATION }")
    lines.append(
        "    struct OfferItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; }"
    )
    lines.append(
        "    struct ConsiderationItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; address recipient; }"
    )
    lines.append(
        "    struct OrderParameters { address offerer; address zone; OfferItem[] offer; ConsiderationItem[] consideration; uint8 orderType; uint256 startTime; uint256 endTime; bytes32 zoneHash; uint256 salt; bytes32 conduitKey; uint256 totalOriginalConsiderationItems; }"
    )
    lines.append("    struct Order { OrderParameters parameters; bytes signature; }")
    lines.append(
        "    struct AdvancedOrder { OrderParameters parameters; uint120 numerator; uint120 denominator; bytes signature; bytes extraData; }"
    )
    lines.append(
        "    struct CriteriaResolver { uint256 orderIndex; Side side; uint256 index; uint256 identifier; bytes32[] criteriaProof; }"
    )
    lines.append(
        "    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool fulfilled);"
    )
    lines.append(
        "    function fulfillAdvancedOrder(AdvancedOrder calldata advancedOrder, CriteriaResolver[] calldata criteriaResolvers, bytes32 fulfillerConduitKey, address recipient) external payable returns (bool fulfilled);"
    )
    lines.append(
        "    function getOrderStatus(bytes32 orderHash) external view returns (bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize);"
    )
    lines.append("}")
    lines.append("")
    lines.append("contract SeaportOrderDebug is Test {")
    lines.append(f"    address constant SEAPORT = {addr_literal(protocol_address)};")
    lines.append(f"    bytes32 constant ORDER_HASH = {order_hash};")
    lines.append("")
    lines.append("    function test_fulfillAdvancedOrder() public {")
    lines.append("        ISeaport seaport = ISeaport(SEAPORT);")
    lines.append(
        "        (bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize) = seaport.getOrderStatus(ORDER_HASH);"
    )
    lines.append(
        '        console2.log("order validated", isValidated ? uint256(1) : uint256(0));'
    )
    lines.append(
        '        console2.log("order cancelled", isCancelled ? uint256(1) : uint256(0));'
    )
    lines.append('        console2.log("order filled", totalFilled);')
    lines.append('        console2.log("order size", totalSize);')
    lines.append("")
    lines.append(
        f"        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[]({len(offer_items)});"
    )
    for i, item in enumerate(offer_items):
        lines.append(f"        offer[{i}] = {item};")
    lines.append("")
    lines.append(
        f"        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[]({len(cons_items)});"
    )
    for i, item in enumerate(cons_items):
        lines.append(f"        consideration[{i}] = {item};")
    lines.append("")
    lines.append(
        "        ISeaport.OrderParameters memory p = ISeaport.OrderParameters({"
    )
    lines.append(f"            offerer: {addr_literal(params['offerer'])},")
    lines.append(f"            zone: {addr_literal(params['zone'])},")
    lines.append("            offer: offer,")
    lines.append("            consideration: consideration,")
    lines.append(f"            orderType: {to_uint(params['orderType'])},")
    lines.append(f"            startTime: {to_uint(params['startTime'])},")
    lines.append(f"            endTime: {to_uint(params['endTime'])},")
    lines.append(f"            zoneHash: {params['zoneHash']},")
    lines.append(f"            salt: {to_uint(params['salt'])},")
    lines.append(f"            conduitKey: {params['conduitKey']},")
    lines.append(
        f"            totalOriginalConsiderationItems: {to_uint(params['totalOriginalConsiderationItems'])}"
    )
    lines.append("        });")
    lines.append("")
    lines.append(
        "        ISeaport.AdvancedOrder memory order = ISeaport.AdvancedOrder({"
    )
    lines.append("            parameters: p,")
    lines.append("            numerator: 1,")
    lines.append("            denominator: 1,")
    lines.append(f'            signature: hex"{sig}",')
    lines.append('            extraData: ""')
    lines.append("        });")
    lines.append("")
    lines.append("        uint256 nowTs = block.timestamp;")
    lines.append("        if (nowTs < p.startTime + 1) { vm.warp(p.startTime + 1); }")
    lines.append(
        '        if (p.endTime != 0 && block.timestamp > p.endTime) { revert("order expired"); }'
    )
    lines.append("")
    lines.append("        uint256 value = 0;")
    lines.append(f"        address buyer = {addr_literal(args.buyer)};")
    if args.as_buyer:
        lines.append("        address payer = buyer;")
    else:
        lines.append("        address payer = p.offerer;")
    lines.append("        for (uint256 i = 0; i < consideration.length; i++) {")
    lines.append(
        "            if (consideration[i].itemType == ISeaport.ItemType.NATIVE) {"
    )
    lines.append("                value += consideration[i].startAmount;")
    lines.append(
        "            } else if (consideration[i].itemType == ISeaport.ItemType.ERC20) {"
    )
    lines.append(
        "                deal(consideration[i].token, payer, consideration[i].startAmount);"
    )
    lines.append("                vm.prank(payer);")
    lines.append(
        "                IERC20(consideration[i].token).approve(SEAPORT, type(uint256).max);"
    )
    lines.append("            }")
    lines.append("        }")
    lines.append('        console2.log("fulfill value", value);')
    lines.append("        if (value > 0) { vm.deal(payer, value); }")
    lines.append("")
    if args.as_buyer:
        lines.append("        vm.prank(buyer);")
    else:
        lines.append("        vm.prank(p.offerer);")
    lines.append(
        "        bool ok = seaport.fulfillAdvancedOrder{ value: value }(order, new ISeaport.CriteriaResolver[](0), bytes32(0), buyer);"
    )
    lines.append('        console2.log("fulfilled", ok ? uint256(1) : uint256(0));')
    lines.append("    }")
    lines.append("}")
    lines.append("")

    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("wrote", args.out)
    print("order_hash", order_hash)
    print("protocol", protocol_address)


if __name__ == "__main__":
    main()
