// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxRoyaltySplitter.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";

/**
 * @title KonduxRoyaltySplitterIntegrationTest
 * @notice Integration tests for the factory + collection + splitter flow
 */
contract KonduxRoyaltySplitterIntegrationTest is Test {
    KonduxImplementation impl;
    KonduxBeaconFactory factory;

    address deployer = address(0x1);
    address collectionAdmin = address(0x2);
    address partner = address(0x3);
    address minter = address(0x4);
    address buyer = address(0x5);
    address seller = address(0x6);

    uint96 constant MANUFACTURER_CUT = 400; // 4%
    uint96 constant PARTNER_CUT = 300; // 3%
    uint96 constant CREATOR_CUT = 300; // 3%

    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);

        vm.startPrank(deployer);
        impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    DEPLOY WITH SPLITTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeployCloneWithSplitter() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true, // deploySplitter
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        // Verify collection deployed
        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        assertEq(collection.name(), "TestCollection");
        assertEq(collection.symbol(), "TEST");

        // Verify splitter deployed and configured
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));
        assertEq(splitter.collection(), collectionAddr);
        assertEq(splitter.manufacturerCutBP(), MANUFACTURER_CUT);
        assertEq(splitter.partnerCutBP(), PARTNER_CUT);
        assertEq(splitter.partnerWallet(), partner);
        assertTrue(splitter.pushModeEnabled());

        // Verify collection has splitter configured
        assertEq(collection.royaltySplitter(), splitterAddr);

        // Verify ERC2981 points to splitter
        (address receiver, uint256 amount) = collection.royaltyInfo(0, 10000);
        assertEq(receiver, splitterAddr);
        assertEq(amount, MANUFACTURER_CUT + PARTNER_CUT + CREATOR_CUT);

        // Verify manufacturer derived from collection admin
        assertEq(splitter.manufacturerWallet(), collectionAdmin);

        // Verify tracking
        assertEq(factory.collectionToSplitter(collectionAddr), splitterAddr);
        assertEq(factory.deployedSplittersCount(), 1);
    }

    function test_DeployCloneWithSplitter_NoSplitter() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            false, // No splitter
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        assertEq(splitterAddr, address(0));
        assertEq(factory.collectionToSplitter(collectionAddr), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    AUTO-REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SafeMint_AutoRegistersCreator() public {
        // Deploy collection with splitter
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Cache the role before prank (prank only applies to next call)
        bytes32 minterRole = collection.MINTER_ROLE();

        // Grant minter role
        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        // Mint a token
        vm.prank(minter);
        uint256 tokenId = collection.safeMint(seller, 12345);

        // Verify creator was auto-registered
        assertTrue(splitter.hasCreatorInfo(tokenId));
        (address regCreator, uint96 cutBP, bool isFirstSale) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, minter, "Minter should be registered as creator");
        assertEq(cutBP, CREATOR_CUT);
        assertTrue(isFirstSale);
    }

    function test_SafeMintWithCreator_ExplicitCreator() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Cache the role before prank
        bytes32 minterRole = collection.MINTER_ROLE();

        // Grant minter role
        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        // Mint with explicit creator and custom cut
        address explicitCreator = address(0x999);
        uint96 customCut = 200;

        vm.prank(minter);
        uint256 tokenId = collection.safeMintWithCreator(seller, 12345, explicitCreator, customCut);

        // Verify explicit creator was registered
        (address regCreator, uint96 cutBP,) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, explicitCreator);
        assertEq(cutBP, customCut);
    }

    /*//////////////////////////////////////////////////////////////
                    FEE_ADMIN MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FeeAdmin_UpdateCutsOnSplitter() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Deployer has FEE_ADMIN_ROLE, update cuts via factory
        vm.prank(deployer);
        factory.setCutsOnSplitter(splitterAddr, 500, 200, 300);

        assertEq(splitter.manufacturerCutBP(), 500);
        assertEq(splitter.partnerCutBP(), 200);
        assertEq(splitter.defaultCreatorCutBP(), 300);
    }

    function test_FeeAdmin_UpdateWalletsOnSplitter() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        address newManufacturer = address(0x888);
        address newPartner = address(0x999);

        vm.prank(deployer);
        factory.setWalletsOnSplitter(splitterAddr, newManufacturer, newPartner);

        assertEq(splitter.manufacturerWallet(), newManufacturer);
        assertEq(splitter.partnerWallet(), newPartner);
    }

    function test_FeeAdmin_RegisterCreatorOnSplitter() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Cache the role before prank
        bytes32 minterRole = collection.MINTER_ROLE();

        // Mint a token
        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        vm.prank(minter);
        uint256 tokenId = collection.safeMint(seller, 12345);

        // FEE_ADMIN overrides creator
        address newCreator = address(0x777);
        vm.prank(deployer);
        factory.registerCreatorOnSplitter(splitterAddr, tokenId, newCreator, 250);

        (address regCreator, uint96 cutBP,) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, newCreator);
        assertEq(cutBP, 250);
    }

    function test_NonFeeAdmin_CannotUpdateCuts() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        // Random user cannot update cuts
        vm.prank(buyer);
        vm.expectRevert();
        factory.setCutsOnSplitter(splitterAddr, 500, 200, 300);
    }

    /*//////////////////////////////////////////////////////////////
                    ROYALTY FLOW E2E TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RoyaltyFlow_FirstSale() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Cache the role before prank (prank only applies to next call)
        bytes32 minterRole = collection.MINTER_ROLE();

        // Mint token
        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        vm.prank(minter);
        uint256 tokenId = collection.safeMint(seller, 12345);

        // Simulate first sale royalty payment (10% of 1 ETH = 0.1 ETH)
        uint256 royaltyAmount = 0.1 ether;
        vm.deal(address(this), royaltyAmount);

        uint256 manufacturerBalBefore = collectionAdmin.balance; // manufacturer is collectionAdmin
        uint256 partnerBalBefore = partner.balance;
        uint256 minterBalBefore = minter.balance; // minter is the creator

        // Send royalty to splitter with token context
        // Collection already has COLLECTION_ROLE, so we can call from the collection
        vm.deal(collectionAddr, royaltyAmount);
        vm.prank(collectionAddr);
        splitter.receivePaymentForToken{value: royaltyAmount}(tokenId);

        // On first sale, creator gets nothing
        // manufacturer + partner should get all
        assertGt(collectionAdmin.balance, manufacturerBalBefore, "Manufacturer should receive");
        assertGt(partner.balance, partnerBalBefore, "Partner should receive");
        // Creator cut goes to manufacturer on first sale
    }

    function test_RoyaltyFlow_SecondarySale() public {
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000,
            collectionAdmin
        );

        vm.prank(deployer);
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            initData,
            true,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT
        );

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        // Cache the role before prank (prank only applies to next call)
        bytes32 minterRole = collection.MINTER_ROLE();

        // Mint token
        vm.prank(collectionAdmin);
        collection.grantRole(minterRole, minter);

        vm.prank(minter);
        uint256 tokenId = collection.safeMint(seller, 12345);

        // First sale - call from collection which has COLLECTION_ROLE
        vm.deal(collectionAddr, 1 ether);
        vm.prank(collectionAddr);
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        // Verify first sale marked
        (,, bool isFirstSale) = splitter.getCreatorInfo(tokenId);
        assertFalse(isFirstSale, "Should no longer be first sale");

        // Secondary sale
        uint256 minterBalBefore = minter.balance;

        vm.prank(collectionAddr);
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        // Now creator (minter) should receive their share
        assertGt(minter.balance, minterBalBefore, "Creator should receive on secondary sale");
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE COLLECTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleCollections_IndependentSplitters() public {
        // Deploy two collections with splitters
        bytes memory initData1 = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "Collection1",
            "COL1",
            1000,
            collectionAdmin
        );

        bytes memory initData2 = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "Collection2",
            "COL2",
            1000,
            buyer // different admin
        );

        vm.startPrank(deployer);
        (address col1, address splitter1) = factory.deployCloneWithSplitter(
            initData1, true, partner, 400, 300, 300
        );
        (address col2, address splitter2) = factory.deployCloneWithSplitter(
            initData2, true, address(0x111), 500, 200, 300
        );
        vm.stopPrank();

        // Verify independent configurations
        KonduxRoyaltySplitter s1 = KonduxRoyaltySplitter(payable(splitter1));
        KonduxRoyaltySplitter s2 = KonduxRoyaltySplitter(payable(splitter2));

        assertEq(s1.manufacturerCutBP(), 400);
        assertEq(s2.manufacturerCutBP(), 500);

        assertEq(s1.partnerWallet(), partner);
        assertEq(s2.partnerWallet(), address(0x111));

        assertEq(s1.manufacturerWallet(), collectionAdmin);
        assertEq(s2.manufacturerWallet(), buyer);

        // Verify tracking
        assertEq(factory.deployedSplittersCount(), 2);
        assertEq(factory.collectionToSplitter(col1), splitter1);
        assertEq(factory.collectionToSplitter(col2), splitter2);
    }
}
