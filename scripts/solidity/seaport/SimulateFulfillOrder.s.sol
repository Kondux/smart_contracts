// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

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

    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey)
        external
        payable
        returns (bool fulfilled);

    function getOrderHash(OrderComponents calldata order) external view returns (bytes32);
    function getCounter(address offerer) external view returns (uint256);

    function information() external view returns (
        string memory version,
        bytes32 domainSeparator,
        address conduitController
    );
}

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract SimulateFulfillOrderScript is Script {
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address constant ROYALTY_RECEIVER = 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114;

    // OpenSea conduit key
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
    // OpenSea conduit address (derived from key)
    address constant CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== Seaport Order Creation & Simulation ===");
        console2.log("");
        console2.log("Seller (offerer):", seller);
        console2.log("NFT:", NFT);
        console2.log("Token ID: 6");
        console2.log("");

        // Build the order
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: 6,
            startAmount: 1,
            endAmount: 1
        });

        // Total: 0.001 ETH = 1000000000000000 wei
        // Seller: 94% = 940000000000000
        // OpenSea: 1% = 10000000000000
        // Royalty: 5% = 50000000000000
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

        // Get counter for offerer
        uint256 counter = ISeaport(SEAPORT).getCounter(seller);
        console2.log("Seller counter:", counter);

        // Order times
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        // Create order components for hashing
        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: address(0),  // No zone for FULL_OPEN
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, seller, uint256(6)))),
            conduitKey: CONDUIT_KEY,
            counter: counter
        });

        // Get order hash
        bytes32 orderHash = ISeaport(SEAPORT).getOrderHash(components);
        console2.log("Order hash:");
        console2.logBytes32(orderHash);

        // Get domain separator
        (, bytes32 domainSeparator,) = ISeaport(SEAPORT).information();
        console2.log("Domain separator:");
        console2.logBytes32(domainSeparator);

        // Create EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));
        console2.log("EIP-712 digest:");
        console2.logBytes32(digest);

        // Sign the order
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        console2.log("Signature created, length:", signature.length);

        // Create order parameters (same as components but without counter)
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

        // Check if seller has approved conduit
        bool isApproved = IERC721(NFT).isApprovedForAll(seller, CONDUIT);
        console2.log("");
        console2.log("Seller approved conduit:", isApproved);

        if (!isApproved) {
            console2.log("Approving conduit for seller...");
            vm.prank(seller);
            IERC721(NFT).setApprovalForAll(CONDUIT, true);
            console2.log("Conduit approved!");
        }

        // Simulate fulfillment
        console2.log("");
        console2.log("=== Simulating Order Fulfillment ===");

        address buyer = 0x9767a2B120614F526e923DAAF89843EC7C2292d7;
        uint256 totalPrice = 1000000000000000;

        console2.log("Buyer:", buyer);
        console2.log("Total price:", totalPrice, "wei (0.001 ETH)");

        vm.deal(buyer, 10 ether);

        vm.prank(buyer);
        try ISeaport(SEAPORT).fulfillOrder{value: totalPrice}(order, bytes32(0)) returns (bool fulfilled) {
            if (fulfilled) {
                console2.log("");
                console2.log("[SUCCESS] Order fulfilled!");
                console2.log("NFT transferred from", seller, "to", buyer);
            } else {
                console2.log("[FAILED] fulfillOrder returned false");
            }
        } catch Error(string memory reason) {
            console2.log("");
            console2.log("[REVERTED]", reason);
        } catch (bytes memory data) {
            console2.log("");
            console2.log("[REVERTED] Low-level error, selector:");
            if (data.length >= 4) {
                bytes4 selector;
                assembly { selector := mload(add(data, 32)) }
                console2.logBytes4(selector);
            }
            console2.logBytes(data);
        }
    }
}
