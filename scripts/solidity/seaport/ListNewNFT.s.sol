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

contract ListNewNFTScript is Script {
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant NFT = 0xdC75300bAbaC28BA2A28393D3494DeEeE452E361;  // NEW NFT
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address constant OPENSEA_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;  // OpenSea Signing Zone
    address constant ROYALTY_SPLITTER = 0xEA4F2710def06Ee87acDC8d449A198A08E650B64;  // Royalty recipient
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;

    uint256 constant TOKEN_ID = 1;
    uint256 constant TOTAL_PRICE = 1000000000000000; // 0.001 ETH
    uint256 constant CREATOR_FEE_BP = 500; // 5% royalty

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== OpenSea Listing for New Collection ===");
        console2.log("Seller:", seller);
        console2.log("NFT:", NFT);
        console2.log("Token ID:", TOKEN_ID);
        console2.log("Price: 0.001 ETH");
        console2.log("");

        // Fee calculations
        uint256 openseaFee = TOTAL_PRICE * 100 / 10000;  // 1% OpenSea fee
        uint256 creatorFee = TOTAL_PRICE * CREATOR_FEE_BP / 10000;  // 5% creator fee
        uint256 sellerAmount = TOTAL_PRICE - openseaFee - creatorFee;

        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: TOKEN_ID,
            startAmount: 1,
            endAmount: 1
        });

        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);

        // Seller payment
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: sellerAmount,
            endAmount: sellerAmount,
            recipient: payable(seller)
        });

        // OpenSea fee (1%)
        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: openseaFee,
            endAmount: openseaFee,
            recipient: payable(OPENSEA_FEE)
        });

        // Creator fee (5% royalty)
        consideration[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: creatorFee,
            endAmount: creatorFee,
            recipient: payable(ROYALTY_SPLITTER)
        });

        uint256 counter = ISeaport(SEAPORT).getCounter(seller);
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, seller, TOKEN_ID, "newcollection"));

        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: OPENSEA_ZONE,
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_RESTRICTED,  // Order type 2 for OpenSea
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
        console2.log("Seller Amount:", sellerAmount);
        console2.log("OpenSea Fee:", openseaFee);
        console2.log("Creator Fee:", creatorFee);
        console2.log("");
        console2.log("Signature:");
        console2.logBytes(signature);
        console2.log("");

        // Output individual values for manual JSON assembly
        console2.log("=== Values for OpenSea Order JSON ===");
        console2.log("offerer:", seller);
        console2.log("zone:", OPENSEA_ZONE);
        console2.log("startTime:", startTime);
        console2.log("endTime:", endTime);
        console2.log("token:", NFT);
        console2.log("tokenId:", TOKEN_ID);
        console2.log("sellerAmount:", sellerAmount);
        console2.log("openseaFee:", openseaFee);
        console2.log("creatorFee:", creatorFee);
        console2.log("royaltySplitter:", ROYALTY_SPLITTER);
        console2.log("salt:");
        console2.logBytes32(salt);
        console2.log("signature:");
        console2.logBytes(signature);
    }
}
