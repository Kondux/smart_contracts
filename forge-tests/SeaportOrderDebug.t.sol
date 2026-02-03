// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ISeaport {
    enum ItemType { NATIVE, ERC20, ERC721, ERC1155, ERC721_WITH_CRITERIA, ERC1155_WITH_CRITERIA }
    enum Side { OFFER, CONSIDERATION }
    struct OfferItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; }
    struct ConsiderationItem { ItemType itemType; address token; uint256 identifierOrCriteria; uint256 startAmount; uint256 endAmount; address recipient; }
    struct OrderParameters { address offerer; address zone; OfferItem[] offer; ConsiderationItem[] consideration; uint8 orderType; uint256 startTime; uint256 endTime; bytes32 zoneHash; uint256 salt; bytes32 conduitKey; uint256 totalOriginalConsiderationItems; }
    struct Order { OrderParameters parameters; bytes signature; }
    struct AdvancedOrder { OrderParameters parameters; uint120 numerator; uint120 denominator; bytes signature; bytes extraData; }
    struct CriteriaResolver { uint256 orderIndex; Side side; uint256 index; uint256 identifier; bytes32[] criteriaProof; }
    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool fulfilled);
    function fulfillAdvancedOrder(AdvancedOrder calldata advancedOrder, CriteriaResolver[] calldata criteriaResolvers, bytes32 fulfillerConduitKey, address recipient) external payable returns (bool fulfilled);
    function getOrderStatus(bytes32 orderHash) external view returns (bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize);
}

contract SeaportOrderDebug is Test {
    address constant SEAPORT = address(uint160(uint256(0x000000000000000068f116a894984e2db1123eb395)));
    bytes32 constant ORDER_HASH = 0xab5d9c0ede21ffd35ae7385d674cf3f51a1b1ce0f02884d9a24afe2ef63671ee;

    function test_fulfillAdvancedOrder() public {
        ISeaport seaport = ISeaport(SEAPORT);
        (bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize) = seaport.getOrderStatus(ORDER_HASH);
        console2.log("order validated", isValidated ? uint256(1) : uint256(0));
        console2.log("order cancelled", isCancelled ? uint256(1) : uint256(0));
        console2.log("order filled", totalFilled);
        console2.log("order size", totalSize);

        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem(ISeaport.ItemType(2), address(uint160(uint256(0x00c410f83c9b444d72799f83a45a4b5b2fe979e2ee))), 6, 1, 1);

        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);
        consideration[0] = ISeaport.ConsiderationItem(ISeaport.ItemType(0), address(uint160(uint256(0x000000000000000000000000000000000000000000))), 0, 379140000000000, 379140000000000, address(uint160(uint256(0x0074c6192d6d9ef8440323dbe5e3a85fc6830f4dc7))));
        consideration[1] = ISeaport.ConsiderationItem(ISeaport.ItemType(0), address(uint160(uint256(0x000000000000000000000000000000000000000000))), 0, 4260000000000, 4260000000000, address(uint160(uint256(0x000000a26b00c1f0df003000390027140000faa719))));
        consideration[2] = ISeaport.ConsiderationItem(ISeaport.ItemType(0), address(uint160(uint256(0x000000000000000000000000000000000000000000))), 0, 42600000000000, 42600000000000, address(uint160(uint256(0x00f2e21db6bee5797a9c9a38c4653bcb81a2695227))));

        ISeaport.OrderParameters memory p = ISeaport.OrderParameters({
            offerer: address(uint160(uint256(0x0074c6192d6d9ef8440323dbe5e3a85fc6830f4dc7))),
            zone: address(uint160(uint256(0x00000056f7000000ece9003ca63978907a00ffd100))),
            offer: offer,
            consideration: consideration,
            orderType: 2,
            startTime: 1770054225,
            endTime: 1772646225,
            zoneHash: 0x0000000000000000000000000000000000000000000000000000000000000000,
            salt: 84892885484896681528822827396150734848187592199240405701034439319127985427916,
            conduitKey: 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000,
            totalOriginalConsiderationItems: 3
        });

        ISeaport.AdvancedOrder memory order = ISeaport.AdvancedOrder({
            parameters: p,
            numerator: 1,
            denominator: 1,
            signature: hex"",
            extraData: ""
        });

        uint256 nowTs = block.timestamp;
        if (nowTs < p.startTime + 1) { vm.warp(p.startTime + 1); }
        if (p.endTime != 0 && block.timestamp > p.endTime) { revert("order expired"); }

        uint256 value = 0;
        address buyer = address(uint160(uint256(0x00000000000000000000000000000000000000beef)));
        address payer = p.offerer;
        for (uint256 i = 0; i < consideration.length; i++) {
            if (consideration[i].itemType == ISeaport.ItemType.NATIVE) {
                value += consideration[i].startAmount;
            } else if (consideration[i].itemType == ISeaport.ItemType.ERC20) {
                deal(consideration[i].token, payer, consideration[i].startAmount);
                vm.prank(payer);
                IERC20(consideration[i].token).approve(SEAPORT, type(uint256).max);
            }
        }
        console2.log("fulfill value", value);
        if (value > 0) { vm.deal(payer, value); }

        vm.prank(p.offerer);
        bool ok = seaport.fulfillAdvancedOrder{ value: value }(order, new ISeaport.CriteriaResolver[](0), bytes32(0), buyer);
        console2.log("fulfilled", ok ? uint256(1) : uint256(0));
    }
}
