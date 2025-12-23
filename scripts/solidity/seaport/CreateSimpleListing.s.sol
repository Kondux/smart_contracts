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

    function getOrderHash(OrderComponents calldata order) external view returns (bytes32);
    function getCounter(address offerer) external view returns (uint256);
    function information() external view returns (string memory version, bytes32 domainSeparator, address conduitController);
}

/**
 * @title CreateSimpleListing
 * @notice Creates a simple FULL_OPEN listing without zone, letting OpenSea add royalties
 */
contract CreateSimpleListingScript is Script {
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;

    uint256 constant TOKEN_ID = 9;
    uint256 constant TOTAL_PRICE = 1000000000000000; // 0.001 ETH

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== Simple Seaport Listing ===");
        console2.log("Seller:", seller);
        console2.log("Token ID:", TOKEN_ID);
        console2.log("Price: 0.001 ETH");
        console2.log("");

        // Simple split: 99% to seller, 1% to OpenSea
        // Let OpenSea add the creator fee from their indexed data
        uint256 sellerAmount = 990000000000000; // 99%
        uint256 openseaFee = 10000000000000;    // 1%

        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: TOKEN_ID,
            startAmount: 1,
            endAmount: 1
        });

        // Only 2 considerations: seller + OpenSea fee
        // OpenSea will add the royalty when displaying/fulfilling
        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](2);

        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: sellerAmount,
            endAmount: sellerAmount,
            recipient: payable(seller)
        });

        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: openseaFee,
            endAmount: openseaFee,
            recipient: payable(OPENSEA_FEE)
        });

        uint256 counter = ISeaport(SEAPORT).getCounter(seller);
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, seller, TOKEN_ID, "simple"));

        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: address(0),  // No zone for FULL_OPEN
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(salt),
            conduitKey: CONDUIT_KEY,
            counter: counter
        });

        bytes32 orderHash = ISeaport(SEAPORT).getOrderHash(components);
        (, bytes32 domainSeparator,) = ISeaport(SEAPORT).information();
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, orderHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        console2.log("Order Hash:");
        console2.logBytes32(orderHash);
        console2.log("");
        console2.log("Start:", startTime);
        console2.log("End:", endTime);
        console2.log("Counter:", counter);
        console2.log("");

        // Output JSON
        console2.log("=== Order JSON ===");
        console2.log("{");
        console2.log('  "parameters": {');
        console2.log('    "offerer": "%s",', seller);
        console2.log('    "zone": "0x0000000000000000000000000000000000000000",');
        console2.log('    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",');
        console2.log('    "startTime": "%s",', startTime);
        console2.log('    "endTime": "%s",', endTime);
        console2.log('    "orderType": 0,');
        console2.log('    "offer": [{"itemType": 2, "token": "%s", "identifierOrCriteria": "%s", "startAmount": "1", "endAmount": "1"}],', NFT, TOKEN_ID);
        console2.log('    "consideration": [');
        console2.log('      {"itemType": 0, "token": "0x0000000000000000000000000000000000000000", "identifierOrCriteria": "0", "startAmount": "%s", "endAmount": "%s", "recipient": "%s"},', sellerAmount, sellerAmount, seller);
        console2.log('      {"itemType": 0, "token": "0x0000000000000000000000000000000000000000", "identifierOrCriteria": "0", "startAmount": "%s", "endAmount": "%s", "recipient": "%s"}', openseaFee, openseaFee, OPENSEA_FEE);
        console2.log('    ],');
        console2.log('    "totalOriginalConsiderationItems": 2,');
        console2.log('    "salt": "%s",', vm.toString(salt));
        console2.log('    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",');
        console2.log('    "counter": "%s"', counter);
        console2.log('  },');
        console2.log('  "signature": "%s",', vm.toString(signature));
        console2.log('  "protocol_address": "0x0000000000000068F116a894984e2DB1123eB395"');
        console2.log("}");
    }
}
