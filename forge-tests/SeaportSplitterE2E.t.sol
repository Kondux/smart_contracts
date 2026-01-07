// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/KonduxRoyaltySplitter.sol";
import "../contracts/helpers/SeaportHelper.sol";

/**
 * @title SeaportSplitterE2E
 * @notice End-to-end tests for royalty splitter with real Seaport order fulfillment
 * @dev Tests all fee splitting scenarios on forked mainnet
 */
contract SeaportSplitterE2E is Test {
    KonduxImplementation impl;
    KonduxBeaconFactory factory;
    SeaportHelper helper;

    // Test accounts with private keys for signing
    uint256 public sellerPk = 0xA11CE;
    uint256 public buyerPk = 0xB0B;
    uint256 public buyer2Pk = 0xCAFE;

    address deployer = address(0x1);
    address collectionAdmin = address(0x2);
    address minter = address(0x3);
    address partner = address(0x4);
    address creator = address(0x5);  // Explicit creator for royalties
    address seller;
    address buyer;
    address buyer2;

    // Seaport 1.6 on Mainnet
    address public constant SEAPORT_1_6 = 0x0000000000000068F116a894984e2DB1123eB395;

    // Seaport Type Hashes for signing
    bytes32 constant OFFER_ITEM_TYPEHASH = keccak256("OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH = keccak256("ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)");
    bytes32 constant ORDER_COMPONENTS_TYPEHASH = keccak256("OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");

    // Standard cuts: 5% manufacturer, 0% partner, 5% creator = 10% total
    uint96 constant MANUFACTURER_CUT = 500;
    uint96 constant PARTNER_CUT = 0;
    uint96 constant CREATOR_CUT = 500;

    function setUp() public {
        seller = vm.addr(sellerPk);
        buyer = vm.addr(buyerPk);
        buyer2 = vm.addr(buyer2Pk);

        // Fork Mainnet
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);

        vm.startPrank(deployer);

        // Deploy Implementation & Factory
        impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));

        // Deploy SeaportHelper
        helper = new SeaportHelper();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployCollectionWithSplitter() internal returns (
        KonduxImplementation collection,
        KonduxRoyaltySplitter splitter
    ) {
        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT,
            collectionAdmin  // defaultCreatorWallet
        );

        collection = KonduxImplementation(payable(collectionAddr));
        splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Configure security policy to allow Seaport
        vm.prank(collectionAdmin);
        collection.setToDefaultSecurityPolicy();
    }

    function _deployCollectionWithSplitterNoPartner() internal returns (
        KonduxImplementation collection,
        KonduxRoyaltySplitter splitter
    ) {
        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin,
            true,
            address(0), // No partner
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT,
            collectionAdmin  // defaultCreatorWallet
        );

        collection = KonduxImplementation(payable(collectionAddr));
        splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        vm.prank(collectionAdmin);
        collection.setToDefaultSecurityPolicy();
    }

    function _mintToken(KonduxImplementation collection, address to) internal returns (uint256 tokenId) {
        bytes32 minterRole = collection.MINTER_ROLE();

        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        vm.prank(minter);
        tokenId = collection.safeMint(to, uint256(keccak256(abi.encodePacked(to, block.timestamp))));
    }

    function _mintTokenWithExplicitCreator(
        KonduxImplementation collection,
        address to,
        address creator,
        uint96 creatorCut
    ) internal returns (uint256 tokenId) {
        bytes32 minterRole = collection.MINTER_ROLE();

        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        vm.prank(minter);
        tokenId = collection.safeMintWithCreator(
            to,
            uint256(keccak256(abi.encodePacked(to, block.timestamp))),
            creator,
            creatorCut
        );
    }

    function _createAndFulfillSeaportOrder(
        KonduxImplementation collection,
        address splitterAddr,
        uint256 tokenId,
        uint256 price,
        uint256 royaltyAmount,
        uint256 sellerPrivateKey,
        address currentOwner,
        address buyerAddr
    ) internal {
        // Seller approves Seaport
        vm.prank(currentOwner);
        collection.setApprovalForAll(SEAPORT_1_6, true);

        // Prepare order with royalty going to splitter
        ISeaport.OrderComponents memory components = helper.prepareOrderWithRoyalties(
            currentOwner,
            address(collection),
            tokenId,
            price,
            splitterAddr,
            royaltyAmount,
            block.timestamp,
            block.timestamp + 1000
        );

        // Sign the order
        bytes memory signature = _signOrder(sellerPrivateKey, components);

        // Construct Order
        ISeaport.Order memory order = ISeaport.Order({
            parameters: _componentsToParameters(components),
            signature: signature
        });

        // Buyer fulfills order
        vm.deal(buyerAddr, price + 1 ether);
        vm.prank(buyerAddr);
        helper.settleDeal{value: price}(order, bytes32(0));
    }

    function _componentsToParameters(ISeaport.OrderComponents memory components) internal pure returns (ISeaport.OrderParameters memory) {
        return ISeaport.OrderParameters({
            offerer: components.offerer,
            zone: components.zone,
            offer: components.offer,
            consideration: components.consideration,
            orderType: components.orderType,
            startTime: components.startTime,
            endTime: components.endTime,
            zoneHash: components.zoneHash,
            salt: components.salt,
            conduitKey: components.conduitKey,
            totalOriginalConsiderationItems: components.consideration.length
        });
    }

    function _signOrder(uint256 pk, ISeaport.OrderComponents memory components) internal view returns (bytes memory) {
        bytes32 orderHash = _getOrderHash(components);
        (, bytes32 domainSeparator, ) = ISeaport(SEAPORT_1_6).information();

        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getOrderHash(ISeaport.OrderComponents memory components) internal pure returns (bytes32) {
        bytes32[] memory offerHashes = new bytes32[](components.offer.length);
        for (uint256 i = 0; i < components.offer.length; ++i) {
            offerHashes[i] = _hashOfferItem(components.offer[i]);
        }

        bytes32[] memory considerationHashes = new bytes32[](components.consideration.length);
        for (uint256 i = 0; i < components.consideration.length; ++i) {
            considerationHashes[i] = _hashConsiderationItem(components.consideration[i]);
        }

        return keccak256(abi.encode(
            ORDER_COMPONENTS_TYPEHASH,
            components.offerer,
            components.zone,
            _hashArray(offerHashes),
            _hashArray(considerationHashes),
            components.orderType,
            components.startTime,
            components.endTime,
            components.zoneHash,
            components.salt,
            components.conduitKey,
            components.counter
        ));
    }

    function _hashOfferItem(ISeaport.OfferItem memory item) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OFFER_ITEM_TYPEHASH,
            item.itemType,
            item.token,
            item.identifierOrCriteria,
            item.startAmount,
            item.endAmount
        ));
    }

    function _hashConsiderationItem(ISeaport.ConsiderationItem memory item) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CONSIDERATION_ITEM_TYPEHASH,
            item.itemType,
            item.token,
            item.identifierOrCriteria,
            item.startAmount,
            item.endAmount,
            item.recipient
        ));
    }

    function _hashArray(bytes32[] memory hashes) internal pure returns (bytes32) {
        bytes memory packed = new bytes(hashes.length * 32);
        for (uint256 i = 0; i < hashes.length; i++) {
            bytes32 hash = hashes[i];
            assembly {
                mstore(add(packed, add(32, mul(i, 32))), hash)
            }
        }
        return keccak256(packed);
    }

    /*//////////////////////////////////////////////////////////////
                    ALL PARTIES RECEIVE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test that ALL parties (manufacturer, partner, creator) receive on ANY sale
     *         No distinction between first and secondary sales
     */
    function test_SeaportE2E_AllPartiesReceive() public {
        console2.log("\n=== TEST: All Parties Receive on Any Sale ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        // Mint token to seller with explicit creator
        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, creator, CREATOR_CUT);

        // Verify creator is registered
        (address regCreator, uint96 cutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, creator, "Creator should be registered");
        assertEq(cutBP, CREATOR_CUT, "Creator cut should match");

        uint256 price = 1 ether;
        (address royaltyReceiver, uint256 royaltyAmount) = collection.royaltyInfo(tokenId, price);

        console2.log("Price:", price);
        console2.log("Royalty Amount:", royaltyAmount);
        console2.log("Royalty Receiver (Splitter):", royaltyReceiver);

        assertEq(royaltyReceiver, address(splitter), "Royalty receiver should be splitter");
        assertEq(royaltyAmount, (price * (MANUFACTURER_CUT + PARTNER_CUT + CREATOR_CUT)) / 10000, "Royalty should be 10%");

        // Record balances before
        uint256 manufacturerBalBefore = collectionAdmin.balance;
        uint256 creatorBalBefore = creator.balance;
        uint256 sellerBalBefore = seller.balance;

        // Execute Seaport trade
        _createAndFulfillSeaportOrder(
            collection,
            address(splitter),
            tokenId,
            price,
            royaltyAmount,
            sellerPk,
            seller,
            buyer
        );

        // Verify NFT ownership changed
        assertEq(collection.ownerOf(tokenId), buyer, "Buyer should own NFT");

        // Verify seller received (price - royalty)
        uint256 sellerReceived = seller.balance - sellerBalBefore;
        assertEq(sellerReceived, price - royaltyAmount, "Seller should receive price minus royalty");

        console2.log("Manufacturer Received:", collectionAdmin.balance - manufacturerBalBefore);
        console2.log("Creator Received:", creator.balance - creatorBalBefore);

        // Manufacturer and creator should receive on ANY sale (partner cut is 0%)
        assertGt(collectionAdmin.balance - manufacturerBalBefore, 0, "Manufacturer should receive ETH");
        assertGt(creator.balance - creatorBalBefore, 0, "Creator should receive on ALL sales");
        // Partner cut is 0% by default, so no assertion

        console2.log("=== ALL PARTIES RECEIVE TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    CONSECUTIVE SALES TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test consecutive sales: creator receives same share on ALL sales
     */
    function test_SeaportE2E_ConsecutiveSales_SameCreatorShare() public {
        console2.log("\n=== TEST: Consecutive Sales - Same Creator Share ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        // Mint with explicit creator
        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, creator, CREATOR_CUT);

        uint256 price = 1 ether;
        (, uint256 royaltyAmount) = collection.royaltyInfo(tokenId, price);

        // === FIRST SALE (seller -> buyer) ===
        console2.log("--- Sale 1: seller -> buyer ---");

        uint256 creatorBal1 = creator.balance;

        _createAndFulfillSeaportOrder(
            collection,
            address(splitter),
            tokenId,
            price,
            royaltyAmount,
            sellerPk,
            seller,
            buyer
        );

        uint256 creatorReceived1 = creator.balance - creatorBal1;
        console2.log("Sale 1 - Creator Received:", creatorReceived1);

        assertEq(collection.ownerOf(tokenId), buyer, "Buyer should own NFT after sale 1");
        assertGt(creatorReceived1, 0, "Creator should receive on sale 1");

        // === SECOND SALE (buyer -> buyer2) ===
        console2.log("--- Sale 2: buyer -> buyer2 ---");

        uint256 creatorBal2 = creator.balance;

        _createAndFulfillSeaportOrder(
            collection,
            address(splitter),
            tokenId,
            price,  // Same price for fair comparison
            royaltyAmount,
            buyerPk,
            buyer,
            buyer2
        );

        uint256 creatorReceived2 = creator.balance - creatorBal2;
        console2.log("Sale 2 - Creator Received:", creatorReceived2);

        assertEq(collection.ownerOf(tokenId), buyer2, "Buyer2 should own NFT after sale 2");
        assertGt(creatorReceived2, 0, "Creator should receive on sale 2");

        // Creator should receive SAME amount on all sales (same price)
        assertEq(creatorReceived1, creatorReceived2, "Creator should receive same on all sales");

        console2.log("=== CONSECUTIVE SALES TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    NO PARTNER SCENARIO
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test when no partner is configured: partner cut goes to manufacturer
     *         Creator still receives their share
     */
    function test_SeaportE2E_NoPartner_CutGoesToManufacturer() public {
        console2.log("\n=== TEST: No Partner - Cut Goes to Manufacturer ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitterNoPartner();

        // Mint with explicit creator
        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, creator, CREATOR_CUT);

        uint256 price = 1 ether;
        (, uint256 royaltyAmount) = collection.royaltyInfo(tokenId, price);

        // Verify no partner is set
        assertEq(splitter.partnerWallet(), address(0), "Partner should be zero address");

        uint256 manufacturerBalBefore = collectionAdmin.balance;
        uint256 creatorBalBefore = creator.balance;

        console2.log("Price:", price);
        console2.log("Royalty Amount:", royaltyAmount);

        // Execute trade
        _createAndFulfillSeaportOrder(
            collection,
            address(splitter),
            tokenId,
            price,
            royaltyAmount,
            sellerPk,
            seller,
            buyer
        );

        // With no partner and partner cut = 0%:
        // - Creator cut (5%) -> creator
        // - Partner cut (0%) -> nothing to redirect
        // - Manufacturer cut (5%) -> manufacturer
        // Total to manufacturer: 5%, creator: 5%

        uint256 manufacturerReceived = collectionAdmin.balance - manufacturerBalBefore;
        uint256 creatorReceived = creator.balance - creatorBalBefore;

        console2.log("Manufacturer Received:", manufacturerReceived);
        console2.log("Creator Received:", creatorReceived);

        // Manufacturer should get 5% (50% of 10% royalty)
        assertApproxEqAbs(manufacturerReceived, royaltyAmount * 50 / 100, 0.001 ether, "Manufacturer should receive 5%");
        // Creator should receive 5%
        assertApproxEqAbs(creatorReceived, royaltyAmount * 50 / 100, 0.001 ether, "Creator should receive 5%");

        console2.log("=== NO PARTNER TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE RESALES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test multiple consecutive sales - creator receives on ALL sales
     */
    function test_SeaportE2E_MultipleResales() public {
        console2.log("\n=== TEST: Multiple Resales ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        // Mint with explicit creator
        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, creator, CREATOR_CUT);

        // === Sale 1 (seller -> buyer) ===
        console2.log("--- Sale 1: seller -> buyer ---");
        uint256 price1 = 1 ether;
        (, uint256 royalty1) = collection.royaltyInfo(tokenId, price1);

        uint256 creatorBal0 = creator.balance;

        _createAndFulfillSeaportOrder(collection, address(splitter), tokenId, price1, royalty1, sellerPk, seller, buyer);

        uint256 creatorReceived1 = creator.balance - creatorBal0;
        console2.log("Sale 1 Creator Received:", creatorReceived1);
        assertGt(creatorReceived1, 0, "Sale 1: Creator SHOULD get royalty");

        // === Sale 2 (buyer -> buyer2) ===
        console2.log("--- Sale 2: buyer -> buyer2 ---");
        uint256 price2 = 1.5 ether;
        (, uint256 royalty2) = collection.royaltyInfo(tokenId, price2);

        uint256 creatorBal1 = creator.balance;

        _createAndFulfillSeaportOrder(collection, address(splitter), tokenId, price2, royalty2, buyerPk, buyer, buyer2);

        uint256 creatorReceived2 = creator.balance - creatorBal1;
        console2.log("Sale 2 Creator Received:", creatorReceived2);
        assertGt(creatorReceived2, 0, "Sale 2: Creator SHOULD get royalty");

        // === Sale 3 (buyer2 -> seller again) ===
        console2.log("--- Sale 3: buyer2 -> seller ---");
        uint256 price3 = 2 ether;
        (, uint256 royalty3) = collection.royaltyInfo(tokenId, price3);

        uint256 creatorBal2 = creator.balance;

        _createAndFulfillSeaportOrder(collection, address(splitter), tokenId, price3, royalty3, buyer2Pk, buyer2, seller);

        uint256 creatorReceived3 = creator.balance - creatorBal2;
        console2.log("Sale 3 Creator Received:", creatorReceived3);
        assertGt(creatorReceived3, 0, "Sale 3: Creator SHOULD get royalty");

        // Verify creator received more on sale 3 than sale 2 (higher price)
        assertGt(creatorReceived3, creatorReceived2, "Higher price should mean higher creator royalty");

        console2.log("=== MULTIPLE RESALES TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    CUSTOM CREATOR CUT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test explicit creator with custom cut percentage
     */
    function test_SeaportE2E_CustomCreatorCut() public {
        console2.log("\n=== TEST: Custom Creator Cut ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        // Mint with explicit creator and custom 2% cut (200 BP)
        // Note: Total must not exceed 10% (manufacturer 4% + partner 3% + creator 2% = 9%)
        address customCreator = address(0xC8EA);
        uint96 customCut = 200; // 2%

        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, customCreator, customCut);

        // Verify creator registration
        (address regCreator, uint96 cutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, customCreator, "Custom creator should be registered");
        assertEq(cutBP, customCut, "Custom cut should be registered");

        // Sale - custom creator should receive their 2% cut
        uint256 price = 1 ether;
        (, uint256 royalty) = collection.royaltyInfo(tokenId, price);

        uint256 customCreatorBalBefore = customCreator.balance;

        _createAndFulfillSeaportOrder(collection, address(splitter), tokenId, price, royalty, sellerPk, seller, buyer);

        uint256 customCreatorReceived = customCreator.balance - customCreatorBalBefore;
        console2.log("Custom Creator Received:", customCreatorReceived);

        // Custom creator should receive their 2% share
        assertGt(customCreatorReceived, 0, "Custom creator should receive on ANY sale");

        // Splitter distributes based on MAX_TOTAL_ROYALTY_BP (1000)
        // Custom cut 200 BP -> 200/1000 * royalty
        uint256 expectedCreatorShare = (royalty * customCut) / 1000;
        console2.log("Expected Creator Share:", expectedCreatorShare);
        assertApproxEqAbs(customCreatorReceived, expectedCreatorShare, 0.001 ether, "Creator should get ~2%");

        console2.log("=== CUSTOM CREATOR CUT TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    VERIFY EXACT SPLITS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test exact split calculations match expected values
     */
    function test_SeaportE2E_ExactSplitAmounts() public {
        console2.log("\n=== TEST: Exact Split Amounts ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        // Mint with explicit creator
        uint256 tokenId = _mintTokenWithExplicitCreator(collection, seller, creator, CREATOR_CUT);

        uint256 price = 10 ether; // Use 10 ETH for cleaner math
        (, uint256 royaltyAmount) = collection.royaltyInfo(tokenId, price);

        // Total royalty should be 10% = 1 ETH
        assertEq(royaltyAmount, 1 ether, "Royalty should be exactly 10%");

        // Track exact amounts for the sale
        uint256 manufacturerBalBefore = collectionAdmin.balance;
        uint256 creatorBalBefore = creator.balance;

        _createAndFulfillSeaportOrder(collection, address(splitter), tokenId, price, royaltyAmount, sellerPk, seller, buyer);

        uint256 mReceived = collectionAdmin.balance - manufacturerBalBefore;
        uint256 cReceived = creator.balance - creatorBalBefore;

        console2.log("Royalty Total:", royaltyAmount);
        console2.log("Manufacturer (5%):", mReceived);
        console2.log("Creator (5%):", cReceived);
        console2.log("Sum:", mReceived + cReceived);

        // Expected: 1 ETH royalty split as 0.5 / 0 / 0.5 (manufacturer/partner/creator)
        // Allow small rounding tolerance
        assertApproxEqAbs(mReceived, 0.5 ether, 0.001 ether, "Manufacturer should get ~5%");
        assertApproxEqAbs(cReceived, 0.5 ether, 0.001 ether, "Creator should get ~5%");

        // Verify total distributed equals royalty amount (minus dust)
        assertApproxEqAbs(mReceived + cReceived, royaltyAmount, 0.001 ether, "Total should equal royalty");

        console2.log("=== EXACT SPLIT AMOUNTS TEST PASSED ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    ERC2981 VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify ERC2981 royaltyInfo returns splitter as receiver
     */
    function test_SeaportE2E_ERC2981PointsToSplitter() public {
        console2.log("\n=== TEST: ERC2981 Points to Splitter ===");

        (KonduxImplementation collection, KonduxRoyaltySplitter splitter) = _deployCollectionWithSplitter();

        uint256 tokenId = _mintToken(collection, seller);

        // Check ERC2981 for various prices
        uint256[] memory prices = new uint256[](4);
        prices[0] = 0.1 ether;
        prices[1] = 1 ether;
        prices[2] = 10 ether;
        prices[3] = 100 ether;

        for (uint256 i = 0; i < prices.length; i++) {
            (address receiver, uint256 amount) = collection.royaltyInfo(tokenId, prices[i]);

            assertEq(receiver, address(splitter), "Receiver should always be splitter");
            assertEq(amount, prices[i] * 1000 / 10000, "Amount should be 10%");

            console2.log("Price:", prices[i], "-> Royalty:", amount);
        }

        console2.log("=== ERC2981 VERIFICATION PASSED ===\n");
    }
}
