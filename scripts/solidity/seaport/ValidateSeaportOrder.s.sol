// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface ISeaport {
    enum OrderType {
        FULL_OPEN,
        PARTIAL_OPEN,
        FULL_RESTRICTED,
        PARTIAL_RESTRICTED
    }

    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

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

    struct Order {
        OrderParameters parameters;
        bytes signature;
    }

    function validate(Order[] calldata orders) external returns (bool);
    function getCounter(address offerer) external view returns (uint256);
    function information() external view returns (string memory version, bytes32 domainSeparator, address conduitController);
}

contract ValidateSeaportOrder is Script {
    // Seaport 1.6
    ISeaport constant SEAPORT = ISeaport(0x0000000000000068F116a894984e2DB1123eB395);

    // OpenSea SignedZone (for FULL_RESTRICTED orders)
    address constant OPENSEA_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    // OpenSea fee recipient
    address constant OPENSEA_FEE_RECIPIENT = 0x0000a26b00c1F0DF003000390027140000fAa719;

    // OpenSea conduit key
    bytes32 constant OPENSEA_CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;

    function run() external {
        uint256 pk = vm.envUint("PROD_TEST_PK");
        address offerer = vm.addr(pk);

        console2.log("Offerer:", offerer);

        // Config
        address collection = 0x167a45aaC7a4512089eC6d401547351d7c73e66F;
        address royaltySplitter = 0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8;
        uint256 tokenId = 1;
        uint256 price = 0.0001 ether;

        // Timing - use current block timestamp
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 30 days;

        // Calculate fees (1% OpenSea, 10% royalty)
        uint256 openseaFee = price * 100 / 10000;
        uint256 royalty = price * 1000 / 10000;
        uint256 sellerAmount = price - openseaFee - royalty;

        // Get counter
        uint256 counter = SEAPORT.getCounter(offerer);
        console2.log("Counter:", counter);

        // Create offer item (NFT)
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: collection,
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1
        });

        // Create consideration items
        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);

        // Seller receives
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: sellerAmount,
            endAmount: sellerAmount,
            recipient: payable(offerer)
        });

        // OpenSea fee
        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: openseaFee,
            endAmount: openseaFee,
            recipient: payable(OPENSEA_FEE_RECIPIENT)
        });

        // Royalty to splitter
        consideration[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: royalty,
            endAmount: royalty,
            recipient: payable(royaltySplitter)
        });

        // Create salt
        bytes32 salt = keccak256(abi.encodePacked(offerer, block.timestamp, tokenId, "opensea_listing"));

        // Build order parameters
        ISeaport.OrderParameters memory params = ISeaport.OrderParameters({
            offerer: offerer,
            zone: OPENSEA_ZONE,
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_RESTRICTED, // Order type 2
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(salt),
            conduitKey: OPENSEA_CONDUIT_KEY,
            totalOriginalConsiderationItems: 3
        });

        // Build order array (signature is empty for on-chain validation by offerer)
        ISeaport.Order[] memory orders = new ISeaport.Order[](1);
        orders[0] = ISeaport.Order({
            parameters: params,
            signature: "" // Empty for self-validation
        });

        console2.log("\n=== Order Details ===");
        console2.log("Collection:", collection);
        console2.log("Token ID:", tokenId);
        console2.log("Price:", price);
        console2.log("Seller Amount:", sellerAmount);
        console2.log("OpenSea Fee:", openseaFee);
        console2.log("Royalty:", royalty);
        console2.log("Start Time:", startTime);
        console2.log("End Time:", endTime);
        console2.log("Order Type: FULL_RESTRICTED (2)");

        // Validate on-chain
        vm.startBroadcast(pk);
        bool success = SEAPORT.validate(orders);
        vm.stopBroadcast();

        console2.log("\n=== Validation Result ===");
        console2.log("Validated:", success);
    }
}
