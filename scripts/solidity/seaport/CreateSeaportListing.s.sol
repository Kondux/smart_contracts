// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * @title CreateSeaportListing
 * @notice Creates a Seaport listing for OpenSea with proper ERC721C configuration
 *
 * ## SignedZone Explanation
 * A SignedZone is a Seaport zone contract that requires authorization from an off-chain
 * signer (OpenSea's API) before allowing order fulfillment. For ERC721C:
 * - The zone validates that royalties are properly included in the order
 * - When a buyer fulfills, they must include `extraData` with OpenSea's server signature
 * - This signature is obtained by calling OpenSea's fulfillment API
 *
 * OpenSea's SignedZone (Mainnet): 0x000056F7000000EcE9003ca63978907a00FFD100
 *
 * ## OrderType Explanation
 * - FULL_OPEN (0): No zone validation - anyone can fulfill without restrictions
 * - PARTIAL_OPEN (1): Partial fills allowed, no zone validation
 * - FULL_RESTRICTED (2): Zone MUST approve fulfillment - required for ERC721C enforcement
 * - PARTIAL_RESTRICTED (3): Partial fills + zone approval required
 *
 * For ERC721C royalty enforcement, use FULL_RESTRICTED (2) with SignedZone.
 */

interface ISeaport {
    enum ItemType { NATIVE, ERC20, ERC721, ERC1155, ERC721_WITH_CRITERIA, ERC1155_WITH_CRITERIA }
    enum OrderType { FULL_OPEN, PARTIAL_OPEN, FULL_RESTRICTED, PARTIAL_RESTRICTED }

    struct OfferItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }

    struct OrderParameters {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 totalOriginalConsiderationItems;
    }

    struct OrderComponents {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 counter;
    }

    struct Order {
        OrderParameters parameters;
        bytes signature;
    }

    struct AdvancedOrder {
        OrderParameters parameters;
        uint120 numerator;
        uint120 denominator;
        bytes signature;
        bytes extraData;
    }

    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey)
        external payable returns (bool fulfilled);

    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) external payable returns (bool fulfilled);

    function getOrderHash(OrderComponents calldata order) external view returns (bytes32);
    function getCounter(address offerer) external view returns (uint256);
    function information() external view returns (string memory version, bytes32 domainSeparator, address conduitController);

    struct CriteriaResolver {
        uint256 orderIndex;
        uint8 side;
        uint256 index;
        uint256 identifier;
        bytes32[] criteriaProof;
    }
}

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract CreateSeaportListingScript is Script {
    // Seaport 1.6
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;

    // NFT Collection
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;

    // OpenSea SignedZone (for ERC721C enforcement)
    address constant OPENSEA_SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    // OpenSea fee recipient
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;

    // Royalty receiver (splitter contract)
    address constant ROYALTY_RECEIVER = 0x78D12571ffE6Ad78cc01696Eb6e60DE0D99824f6;

    // OpenSea conduit key and address
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
    address constant CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    // Token to list
    uint256 constant TOKEN_ID = 8;

    // Price: 0.001 ETH
    uint256 constant TOTAL_PRICE = 1000000000000000; // 0.001 ETH

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== Seaport Listing Creator (ERC721C Compliant) ===");
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Seller:", seller);
        console2.log("  NFT:", NFT);
        console2.log("  Token ID:", TOKEN_ID);
        console2.log("  Price: 0.001 ETH");
        console2.log("");

        // Verify ownership
        address owner = IERC721(NFT).ownerOf(TOKEN_ID);
        require(owner == seller, "Seller does not own this token");
        console2.log("[OK] Seller owns token", TOKEN_ID);

        // Calculate fee splits (total = 0.001 ETH)
        // Seller: 94% = 940000000000000 wei
        // OpenSea: 1% = 10000000000000 wei
        // Royalty: 5% = 50000000000000 wei
        uint256 sellerAmount = 940000000000000;
        uint256 openseaFee = 10000000000000;
        uint256 royaltyAmount = 50000000000000;

        console2.log("");
        console2.log("Fee Breakdown:");
        console2.log("  Seller receives:", sellerAmount, "wei (94%)");
        console2.log("  OpenSea fee:", openseaFee, "wei (1%)");
        console2.log("  Royalty:", royaltyAmount, "wei (5%)");
        console2.log("  Total:", sellerAmount + openseaFee + royaltyAmount, "wei");

        // Build offer (what seller is selling)
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: TOKEN_ID,
            startAmount: 1,
            endAmount: 1
        });

        // Build consideration (what seller wants in return)
        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);

        // 1. Payment to seller
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: sellerAmount,
            endAmount: sellerAmount,
            recipient: payable(seller)
        });

        // 2. OpenSea fee
        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: openseaFee,
            endAmount: openseaFee,
            recipient: payable(OPENSEA_FEE)
        });

        // 3. Creator royalty
        consideration[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: royaltyAmount,
            endAmount: royaltyAmount,
            recipient: payable(ROYALTY_RECEIVER)
        });

        // Get counter
        uint256 counter = ISeaport(SEAPORT).getCounter(seller);

        // Order times
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        // Create salt
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, seller, TOKEN_ID, "listing"));

        console2.log("");
        console2.log("Order Configuration:");
        console2.log("  OrderType: FULL_RESTRICTED (2) - Required for ERC721C");
        console2.log("  Zone:", OPENSEA_SIGNED_ZONE);
        console2.log("  Start:", startTime);
        console2.log("  End:", endTime);
        console2.log("  Counter:", counter);

        // Create order components for signing
        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: OPENSEA_SIGNED_ZONE,  // SignedZone for ERC721C
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_RESTRICTED,  // Required for zone validation
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(salt),
            conduitKey: CONDUIT_KEY,
            counter: counter
        });

        // Get order hash
        bytes32 orderHash = ISeaport(SEAPORT).getOrderHash(components);

        // Get domain separator
        (, bytes32 domainSeparator,) = ISeaport(SEAPORT).information();

        // Create EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));

        // Sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        console2.log("");
        console2.log("=== Signed Order ===");
        console2.log("Order Hash:");
        console2.logBytes32(orderHash);

        // Output the full order as JSON for OpenSea API
        console2.log("");
        console2.log("=== Order JSON for OpenSea API ===");
        _printOrderJson(components, signature, startTime, endTime, salt);

        // Check conduit approval
        bool isApproved = IERC721(NFT).isApprovedForAll(seller, CONDUIT);
        console2.log("");
        console2.log("Conduit Approval Status:", isApproved ? "APPROVED" : "NOT APPROVED");

        if (!isApproved) {
            console2.log("");
            console2.log("[ACTION REQUIRED] Approve conduit before listing:");
            console2.log("  Run: cast send", NFT);
            console2.log("       'setApprovalForAll(address,bool)'", CONDUIT, "true");
        }

        console2.log("");
        console2.log("=== To List on OpenSea ===");
        console2.log("Option 1: Use OpenSea's UI at https://opensea.io");
        console2.log("Option 2: POST the order to OpenSea's API:");
        console2.log("  POST https://api.opensea.io/v2/orders/ethereum/seaport/listings");
        console2.log("");
        console2.log("Note: For FULL_RESTRICTED orders with SignedZone, fulfillment");
        console2.log("requires extraData from OpenSea's API (obtained when buyer purchases).");
    }

    function _printOrderJson(
        ISeaport.OrderComponents memory c,
        bytes memory sig,
        uint256 startTime,
        uint256 endTime,
        bytes32 salt
    ) internal view {
        console2.log("{");
        console2.log('  "parameters": {');
        console2.log('    "offerer": "%s",', c.offerer);
        console2.log('    "zone": "%s",', c.zone);
        console2.log('    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",');
        console2.log('    "startTime": %s,', startTime);
        console2.log('    "endTime": %s,', endTime);
        console2.log('    "orderType": 2,');
        console2.log('    "offer": [');
        console2.log('      {');
        console2.log('        "itemType": 2,');
        console2.log('        "token": "%s",', c.offer[0].token);
        console2.log('        "identifierOrCriteria": "%s",', c.offer[0].identifierOrCriteria);
        console2.log('        "startAmount": "1",');
        console2.log('        "endAmount": "1"');
        console2.log('      }');
        console2.log('    ],');
        console2.log('    "consideration": [');
        for (uint i = 0; i < c.consideration.length; i++) {
            console2.log('      {');
            console2.log('        "itemType": 0,');
            console2.log('        "token": "0x0000000000000000000000000000000000000000",');
            console2.log('        "identifierOrCriteria": "0",');
            console2.log('        "startAmount": "%s",', c.consideration[i].startAmount);
            console2.log('        "endAmount": "%s",', c.consideration[i].endAmount);
            console2.log('        "recipient": "%s"', c.consideration[i].recipient);
            if (i < c.consideration.length - 1) {
                console2.log('      },');
            } else {
                console2.log('      }');
            }
        }
        console2.log('    ],');
        console2.log('    "totalOriginalConsiderationItems": 3,');
        console2.log('    "salt": "%s",', vm.toString(salt));
        console2.log('    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",');
        console2.log('    "counter": "%s"', c.counter);
        console2.log('  },');
        console2.log('  "signature": "%s"', vm.toString(sig));
        console2.log("}");
    }
}

/**
 * @title SimulateRestrictedFulfillment
 * @notice Simulates fulfilling a FULL_RESTRICTED order
 * @dev Note: Real fulfillment requires extraData from OpenSea's API
 */
contract SimulateRestrictedFulfillmentScript is Script {
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address constant ROYALTY_RECEIVER = 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114;
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
    address constant CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== Simulating FULL_OPEN Order (works without SignedZone) ===");
        console2.log("");

        // For simulation, we use FULL_OPEN since we don't have OpenSea's extraData
        // This works because we've whitelisted the conduit in the transfer validator

        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: 6,
            startAmount: 1,
            endAmount: 1
        });

        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 940000000000000,
            endAmount: 940000000000000,
            recipient: payable(seller)
        });
        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 10000000000000,
            endAmount: 10000000000000,
            recipient: payable(OPENSEA_FEE)
        });
        consideration[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 50000000000000,
            endAmount: 50000000000000,
            recipient: payable(ROYALTY_RECEIVER)
        });

        uint256 counter = ISeaport(SEAPORT).getCounter(seller);
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: address(0),  // No zone for FULL_OPEN
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, seller))),
            conduitKey: CONDUIT_KEY,
            counter: counter
        });

        bytes32 orderHash = ISeaport(SEAPORT).getOrderHash(components);
        (, bytes32 domainSeparator,) = ISeaport(SEAPORT).information();
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, orderHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISeaport.OrderParameters memory params = ISeaport.OrderParameters({
            offerer: seller,
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: components.salt,
            conduitKey: CONDUIT_KEY,
            totalOriginalConsiderationItems: 3
        });

        ISeaport.Order memory order = ISeaport.Order({
            parameters: params,
            signature: signature
        });

        // Approve conduit if needed
        bool isApproved = IERC721(NFT).isApprovedForAll(seller, CONDUIT);
        if (!isApproved) {
            console2.log("Approving conduit...");
            vm.prank(seller);
            IERC721(NFT).setApprovalForAll(CONDUIT, true);
        }

        // Simulate buyer
        address buyer = 0x9767a2B120614F526e923DAAF89843EC7C2292d7;
        vm.deal(buyer, 10 ether);

        console2.log("Buyer:", buyer);
        console2.log("Fulfilling order...");

        vm.prank(buyer);
        try ISeaport(SEAPORT).fulfillOrder{value: 1000000000000000}(order, bytes32(0)) returns (bool fulfilled) {
            if (fulfilled) {
                console2.log("");
                console2.log("[SUCCESS] Order fulfilled!");
                console2.log("Token 6 transferred to buyer");
            }
        } catch (bytes memory data) {
            console2.log("[FAILED]");
            if (data.length >= 4) {
                bytes4 selector;
                assembly { selector := mload(add(data, 32)) }
                console2.logBytes4(selector);
            }
        }
    }
}
