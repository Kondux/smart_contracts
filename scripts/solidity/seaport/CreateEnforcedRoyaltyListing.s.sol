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

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function totalSupply() external view returns (uint256);
}

interface IKonduxNFT {
    function safeMint(address to, uint256 dna) external returns (uint256);
}

/**
 * @title CreateEnforcedRoyaltyListing
 * @notice Creates a FULL_RESTRICTED listing with royalty enforced via SignedZone
 * @dev The royalty is included as a consideration item, and the zone will validate it
 */
contract CreateEnforcedRoyaltyListingScript is Script {
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address constant OPENSEA_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address constant SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;
    address constant ROYALTY_SPLITTER = 0x61190B06C040Ce8829E0a688d2fE5b5ee599272A;
    bytes32 constant CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;

    uint256 constant TOTAL_PRICE = 1000000000000000; // 0.001 ETH

    // Price breakdown WITH royalty baked in:
    // Total buyer pays: 0.001 ETH
    // - Royalty 5%:  50,000,000,000,000 wei (to splitter)
    // - OpenSea 1%:  10,000,000,000,000 wei (OpenSea requires exactly 1%)
    // - Seller 94%: 940,000,000,000,000 wei
    uint256 constant ROYALTY_AMOUNT = 50000000000000;   // 5% royalty
    uint256 constant OPENSEA_AMOUNT = 10000000000000;   // 1% OpenSea fee
    uint256 constant SELLER_AMOUNT = 940000000000000;   // 94% to seller

    function run() external {
        uint256 sellerKey = vm.envUint("PROD_DEPLOYER_PK");
        address seller = vm.addr(sellerKey);

        console2.log("=== Enforced Royalty Seaport Listing ===");
        console2.log("Seller:", seller);
        console2.log("Price: 0.001 ETH");
        console2.log("");

        // Use token 10 (already minted)
        uint256 tokenId = 10;
        console2.log("Token ID:", tokenId);
        console2.log("");

        // Verify ownership
        address owner = IERC721(NFT).ownerOf(tokenId);
        console2.log("Token owner:", owner);
        require(owner == seller, "Seller does not own the token");

        // Create the order
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: NFT,
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1
        });

        // 3 consideration items: seller + OpenSea fee + royalty
        // Royalty is REQUIRED - baked into the order signature
        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](3);

        // Seller receives 94%
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: SELLER_AMOUNT,
            endAmount: SELLER_AMOUNT,
            recipient: payable(seller)
        });

        // OpenSea receives 1%
        consideration[1] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: OPENSEA_AMOUNT,
            endAmount: OPENSEA_AMOUNT,
            recipient: payable(OPENSEA_FEE)
        });

        // Royalty splitter receives 5%
        consideration[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: ROYALTY_AMOUNT,
            endAmount: ROYALTY_AMOUNT,
            recipient: payable(ROYALTY_SPLITTER)
        });

        uint256 counter = ISeaport(SEAPORT).getCounter(seller);
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, seller, tokenId, "enforced"));

        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: seller,
            zone: SIGNED_ZONE,  // SignedZone for OpenSea validation
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_RESTRICTED,  // FULL_RESTRICTED with royalty in consideration
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

        console2.log("=== Order Details ===");
        console2.log("Order Hash:");
        console2.logBytes32(orderHash);
        console2.log("");
        console2.log("Token ID:", tokenId);
        console2.log("Start:", startTime);
        console2.log("End:", endTime);
        console2.log("Counter:", counter);
        console2.log("");
        console2.log("Price Breakdown:");
        console2.log("  Seller (94%):", SELLER_AMOUNT);
        console2.log("  OpenSea (1%):", OPENSEA_AMOUNT);
        console2.log("  Royalty (5%):", ROYALTY_AMOUNT);
        console2.log("  Total:", TOTAL_PRICE);
        console2.log("");

        // Output JSON for OpenSea API
        console2.log("=== Order JSON ===");
        console2.log("{");
        console2.log('  "parameters": {');
        console2.log('    "offerer": "%s",', seller);
        console2.log('    "zone": "%s",', SIGNED_ZONE);
        console2.log('    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",');
        console2.log('    "startTime": "%s",', startTime);
        console2.log('    "endTime": "%s",', endTime);
        console2.log('    "orderType": 2,');
        console2.log('    "offer": [{"itemType": 2, "token": "%s", "identifierOrCriteria": "%s", "startAmount": "1", "endAmount": "1"}],', NFT, tokenId);
        console2.log('    "consideration": [');
        console2.log('      {"itemType": 0, "token": "0x0000000000000000000000000000000000000000", "identifierOrCriteria": "0", "startAmount": "%s", "endAmount": "%s", "recipient": "%s"},', SELLER_AMOUNT, SELLER_AMOUNT, seller);
        console2.log('      {"itemType": 0, "token": "0x0000000000000000000000000000000000000000", "identifierOrCriteria": "0", "startAmount": "%s", "endAmount": "%s", "recipient": "%s"},', OPENSEA_AMOUNT, OPENSEA_AMOUNT, OPENSEA_FEE);
        console2.log('      {"itemType": 0, "token": "0x0000000000000000000000000000000000000000", "identifierOrCriteria": "0", "startAmount": "%s", "endAmount": "%s", "recipient": "%s"}', ROYALTY_AMOUNT, ROYALTY_AMOUNT, ROYALTY_SPLITTER);
        console2.log('    ],');
        console2.log('    "totalOriginalConsiderationItems": 3,');
        console2.log('    "salt": "%s",', vm.toString(salt));
        console2.log('    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",');
        console2.log('    "counter": "%s"', counter);
        console2.log('  },');
        console2.log('  "signature": "%s",', vm.toString(signature));
        console2.log('  "protocol_address": "%s"', SEAPORT);
        console2.log("}");
    }
}
