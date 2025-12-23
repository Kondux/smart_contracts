// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface ISeaport {
    function getCounter(address offerer) external view returns (uint256);
    function information() external view returns (string memory version, bytes32 domainSeparator, address conduitController);
}

contract CreateOpenSeaListing is Script {
    // Seaport 1.6
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;

    // OpenSea SignedZone (for FULL_RESTRICTED orders)
    address constant OPENSEA_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    // OpenSea fee recipient
    address constant OPENSEA_FEE_RECIPIENT = 0x0000a26b00c1F0DF003000390027140000fAa719;

    // OpenSea conduit key
    bytes32 constant OPENSEA_CONDUIT_KEY = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;

    // EIP-712 type hashes
    bytes32 constant OFFER_ITEM_TYPEHASH = keccak256("OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH = keccak256("ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)");
    bytes32 constant ORDER_COMPONENTS_TYPEHASH = keccak256("OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");

    struct OfferItem {
        uint8 itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        uint8 itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address recipient;
    }

    function run() external view {
        // Config - adjust these values
        address offerer = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
        address collection = 0x167a45aaC7a4512089eC6d401547351d7c73e66F;
        address royaltySplitter = 0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8;
        uint256 tokenId = 0;
        uint256 price = 0.0001 ether; // 100000000000000 wei

        // Timing
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 30 days; // 30 day listing

        // Calculate fees
        // OpenSea fee: 1%
        uint256 openseaFee = price * 100 / 10000;
        // Royalty: 10%
        uint256 royalty = price * 1000 / 10000;
        // Seller receives
        uint256 sellerAmount = price - openseaFee - royalty;

        // Get counter from Seaport
        uint256 counter = ISeaport(SEAPORT).getCounter(offerer);

        // Generate random salt
        bytes32 salt = keccak256(abi.encodePacked(offerer, block.timestamp, tokenId, block.number));

        console2.log("\n=== OpenSea Listing Parameters ===");
        console2.log("Collection:", collection);
        console2.log("Token ID:", tokenId);
        console2.log("Price (wei):", price);
        console2.log("OpenSea Fee (wei):", openseaFee);
        console2.log("Royalty (wei):", royalty);
        console2.log("Seller Amount (wei):", sellerAmount);
        console2.log("Counter:", counter);
        console2.log("Start Time:", startTime);
        console2.log("End Time:", endTime);

        // Output JSON for API call
        console2.log("\n=== Order Parameters JSON ===");
        console2.log("{");
        console2.log('  "parameters": {');
        console2.log('    "offerer": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",');
        console2.log('    "zone": "0x000056F7000000EcE9003ca63978907a00FFD100",');
        console2.log('    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",');
        _logUint('    "startTime": "', startTime, '",');
        _logUint('    "endTime": "', endTime, '",');
        console2.log('    "orderType": 2,');
        console2.log('    "offer": [{');
        console2.log('      "itemType": 2,');
        console2.log('      "token": "0x167a45aaC7a4512089eC6d401547351d7c73e66F",');
        _logUint('      "identifierOrCriteria": "', tokenId, '",');
        console2.log('      "startAmount": "1",');
        console2.log('      "endAmount": "1"');
        console2.log('    }],');
        console2.log('    "consideration": [');
        console2.log('      {');
        console2.log('        "itemType": 0,');
        console2.log('        "token": "0x0000000000000000000000000000000000000000",');
        console2.log('        "identifierOrCriteria": "0",');
        _logUint('        "startAmount": "', sellerAmount, '",');
        _logUint('        "endAmount": "', sellerAmount, '",');
        console2.log('        "recipient": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"');
        console2.log('      },');
        console2.log('      {');
        console2.log('        "itemType": 0,');
        console2.log('        "token": "0x0000000000000000000000000000000000000000",');
        console2.log('        "identifierOrCriteria": "0",');
        _logUint('        "startAmount": "', openseaFee, '",');
        _logUint('        "endAmount": "', openseaFee, '",');
        console2.log('        "recipient": "0x0000a26b00c1F0DF003000390027140000fAa719"');
        console2.log('      },');
        console2.log('      {');
        console2.log('        "itemType": 0,');
        console2.log('        "token": "0x0000000000000000000000000000000000000000",');
        console2.log('        "identifierOrCriteria": "0",');
        _logUint('        "startAmount": "', royalty, '",');
        _logUint('        "endAmount": "', royalty, '",');
        console2.log('        "recipient": "0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8"');
        console2.log('      }');
        console2.log('    ],');
        console2.log('    "totalOriginalConsiderationItems": 3,');
        console2.log('    "salt": "', vm.toString(salt), '",');
        console2.log('    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",');
        _logUint('    "counter": "', counter, '"');
        console2.log('  },');
        console2.log('  "signature": "<SIGN_WITH_PRIVATE_KEY>",');
        console2.log('  "protocol_address": "0x0000000000000068F116a894984e2DB1123eB395"');
        console2.log("}");

        // Calculate order hash for signing
        bytes32 orderHash = _computeOrderHash(
            offerer,
            tokenId,
            sellerAmount,
            openseaFee,
            royalty,
            royaltySplitter,
            startTime,
            endTime,
            salt,
            counter
        );

        (, bytes32 domainSeparator, ) = ISeaport(SEAPORT).information();

        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));

        console2.log("\n=== For Signing ===");
        console2.log("Order Hash:", vm.toString(orderHash));
        console2.log("Domain Separator:", vm.toString(domainSeparator));
        console2.log("Digest to Sign:", vm.toString(digest));
        console2.log("Salt:", vm.toString(salt));
    }

    function _logUint(string memory prefix, uint256 value, string memory suffix) internal pure {
        console2.log(string.concat(prefix, vm.toString(value), suffix));
    }

    function _computeOrderHash(
        address offerer,
        uint256 tokenId,
        uint256 sellerAmount,
        uint256 openseaFee,
        uint256 royalty,
        address royaltySplitter,
        uint256 startTime,
        uint256 endTime,
        bytes32 salt,
        uint256 counter
    ) internal pure returns (bytes32) {
        // Hash offer items
        bytes32[] memory offerHashes = new bytes32[](1);
        offerHashes[0] = keccak256(abi.encode(
            OFFER_ITEM_TYPEHASH,
            uint8(2), // ERC721
            address(0x167a45aaC7a4512089eC6d401547351d7c73e66F),
            tokenId,
            uint256(1),
            uint256(1)
        ));

        // Hash consideration items
        bytes32[] memory considerationHashes = new bytes32[](3);
        // Seller
        considerationHashes[0] = keccak256(abi.encode(
            CONSIDERATION_ITEM_TYPEHASH,
            uint8(0), // NATIVE
            address(0),
            uint256(0),
            sellerAmount,
            sellerAmount,
            offerer
        ));
        // OpenSea fee
        considerationHashes[1] = keccak256(abi.encode(
            CONSIDERATION_ITEM_TYPEHASH,
            uint8(0),
            address(0),
            uint256(0),
            openseaFee,
            openseaFee,
            OPENSEA_FEE_RECIPIENT
        ));
        // Royalty
        considerationHashes[2] = keccak256(abi.encode(
            CONSIDERATION_ITEM_TYPEHASH,
            uint8(0),
            address(0),
            uint256(0),
            royalty,
            royalty,
            royaltySplitter
        ));

        return keccak256(abi.encode(
            ORDER_COMPONENTS_TYPEHASH,
            offerer,
            OPENSEA_ZONE,
            keccak256(abi.encodePacked(offerHashes)),
            keccak256(abi.encodePacked(considerationHashes)),
            uint8(2), // FULL_RESTRICTED
            startTime,
            endTime,
            bytes32(0), // zoneHash
            salt,
            OPENSEA_CONDUIT_KEY,
            counter
        ));
    }
}
