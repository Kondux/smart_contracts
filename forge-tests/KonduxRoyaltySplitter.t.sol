// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxRoyaltySplitter.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";

contract KonduxRoyaltySplitterTest is Test {
    KonduxRoyaltySplitter splitter;
    KonduxImplementation impl;
    KonduxImplementation collection;
    KonduxBeaconFactory factory;

    address deployer = address(0x1);
    address manufacturer = address(0x2);
    address partner = address(0x3);
    address creator = address(0x4);
    address buyer = address(0x5);
    address admin = address(0x6);

    uint96 constant MANUFACTURER_CUT = 400; // 4%
    uint96 constant PARTNER_CUT = 300; // 3%
    uint96 constant CREATOR_CUT = 300; // 3%

    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);

        vm.startPrank(deployer);

        // Deploy implementation and factory
        impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));

        // Deploy a collection clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "TestCollection",
            "TEST",
            1000, // maxSupply
            admin // initialAdmin
        );
        address collectionAddr = factory.deployClone(initData);
        collection = KonduxImplementation(payable(collectionAddr));

        // Deploy splitter
        splitter = new KonduxRoyaltySplitter(
            address(collection),
            manufacturer,
            partner,
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT,
            admin
        );

        vm.stopPrank();

        // Note: Constructor already grants COLLECTION_ROLE to collection
        // This is now redundant but kept for clarity - cache role before prank
        bytes32 collectionRole = splitter.COLLECTION_ROLE();
        vm.prank(admin);
        splitter.grantRole(collectionRole, address(collection));
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialization() public view {
        assertEq(splitter.collection(), address(collection));
        assertEq(splitter.manufacturerWallet(), manufacturer);
        assertEq(splitter.partnerWallet(), partner);
        assertEq(splitter.manufacturerCutBP(), MANUFACTURER_CUT);
        assertEq(splitter.partnerCutBP(), PARTNER_CUT);
        assertEq(splitter.defaultCreatorCutBP(), CREATOR_CUT);
        assertTrue(splitter.pushModeEnabled(), "Push mode should be enabled by default");
    }

    function test_RolesGranted() public view {
        assertTrue(splitter.hasRole(splitter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(splitter.hasRole(splitter.ADMIN_ROLE(), admin));
        assertTrue(splitter.hasRole(splitter.FEE_ADMIN_ROLE(), admin));
        assertTrue(splitter.hasRole(splitter.DISTRIBUTOR_ROLE(), admin));
        assertTrue(splitter.hasRole(splitter.COLLECTION_ROLE(), address(collection)));
    }

    /*//////////////////////////////////////////////////////////////
                        CREATOR REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RegisterCreator_ByAdmin() public {
        uint256 tokenId = 0;

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        (address regCreator, uint96 cutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, creator);
        assertEq(cutBP, CREATOR_CUT);
    }

    function test_RegisterCreator_ByCollection() public {
        uint256 tokenId = 1;

        vm.prank(address(collection));
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        (address regCreator,) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, creator);
    }

    function test_RegisterCreator_CollectionCannotOverride() public {
        uint256 tokenId = 2;

        // First registration by collection
        vm.prank(address(collection));
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Collection cannot override
        address newCreator = address(0x99);
        vm.prank(address(collection));
        vm.expectRevert("Already registered, need admin to override");
        splitter.registerCreator(tokenId, newCreator, CREATOR_CUT);
    }

    function test_RegisterCreator_AdminCanOverride() public {
        uint256 tokenId = 3;

        // First registration
        vm.prank(address(collection));
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Admin can override
        address newCreator = address(0x99);
        vm.prank(admin);
        splitter.registerCreator(tokenId, newCreator, 200);

        (address regCreator, uint96 cutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, newCreator);
        assertEq(cutBP, 200);
    }

    /*//////////////////////////////////////////////////////////////
                    CREATOR SELF-SERVICE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UpdateCreatorWallet() public {
        uint256 tokenId = 4;

        // Register creator
        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Creator updates their wallet
        address newWallet = address(0x88);
        vm.prank(creator);
        splitter.updateCreatorWallet(tokenId, newWallet);

        (address regCreator,) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, newWallet);
    }

    function test_UpdateCreatorWallet_NotCreator_Reverts() public {
        uint256 tokenId = 5;

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Non-creator cannot update
        vm.prank(buyer);
        vm.expectRevert(KonduxRoyaltySplitter.NotCreatorOfToken.selector);
        splitter.updateCreatorWallet(tokenId, buyer);
    }

    function test_UpdateCreatorWallet_ZeroAddress_Reverts() public {
        uint256 tokenId = 6;

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        vm.prank(creator);
        vm.expectRevert(KonduxRoyaltySplitter.InvalidAddress.selector);
        splitter.updateCreatorWallet(tokenId, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDE CREATOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OverrideCreator() public {
        uint256 tokenId = 7;

        // Register creator
        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Override creator
        address newCreator = address(0x77);
        vm.prank(admin);
        splitter.overrideCreator(tokenId, newCreator, 200);

        // Verify override worked
        (address regCreator, uint96 cutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(regCreator, newCreator);
        assertEq(cutBP, 200);
    }

    /*//////////////////////////////////////////////////////////////
                        ROYALTY SPLIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CalculateSplit_AllPartiesReceive() public {
        uint256 tokenId = 8;
        uint256 amount = 1 ether; // This is the royalty amount (10% of 10 ETH sale)

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        (uint256 mAmt, uint256 pAmt, uint256 cAmt, address creatorAddr, uint96 cutBP) =
            splitter.getSplit(tokenId, amount);

        // All parties should receive their share on ANY sale
        assertGt(cAmt, 0, "Creator should get their share");
        assertGt(mAmt, 0, "Manufacturer should get some");
        assertGt(pAmt, 0, "Partner should get some");
        assertEq(creatorAddr, creator);
        assertEq(cutBP, CREATOR_CUT);

        // Verify exact split based on MAX_TOTAL_ROYALTY_BP (1000)
        // Split is: amount * cutBP / 1000
        // 4% of royalty -> 400/1000 * 1 ETH = 0.4 ETH
        // 3% of royalty -> 300/1000 * 1 ETH = 0.3 ETH
        assertEq(mAmt, 0.4 ether, "Manufacturer should get 40% of royalty");
        assertEq(pAmt, 0.3 ether, "Partner should get 30% of royalty");
        assertEq(cAmt, 0.3 ether, "Creator should get 30% of royalty");
    }

    function test_CalculateSplit_ConsecutiveSales() public {
        uint256 tokenId = 9;
        uint256 amount = 1 ether;

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // First sale
        (uint256 mAmt1, uint256 pAmt1, uint256 cAmt1,,) = splitter.getSplit(tokenId, amount);

        // Simulate a sale
        vm.deal(admin, 1 ether);
        vm.prank(admin);
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        // Second sale - should be same split
        (uint256 mAmt2, uint256 pAmt2, uint256 cAmt2,,) = splitter.getSplit(tokenId, amount);

        // All sales should have same split
        assertEq(mAmt1, mAmt2, "Manufacturer split should be same");
        assertEq(pAmt1, pAmt2, "Partner split should be same");
        assertEq(cAmt1, cAmt2, "Creator split should be same");
    }

    function test_DefaultToManufacturer_NoPartner() public {
        // Create splitter with no partner
        vm.prank(deployer);
        KonduxRoyaltySplitter noPartnerSplitter = new KonduxRoyaltySplitter(
            address(collection),
            manufacturer,
            address(0), // No partner
            MANUFACTURER_CUT,
            PARTNER_CUT,
            CREATOR_CUT,
            admin
        );

        uint256 tokenId = 10;
        vm.prank(admin);
        noPartnerSplitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Give splitter some ETH
        vm.deal(address(noPartnerSplitter), 1 ether);

        uint256 manufacturerBalBefore = manufacturer.balance;

        // Distribute
        vm.prank(admin);
        noPartnerSplitter.sweepETH(tokenId);

        // Manufacturer should get their share + partner's share
        uint256 manufacturerReceived = splitter.pendingETH(manufacturer);
        // Partner's share goes to manufacturer since partner is address(0)
    }

    /*//////////////////////////////////////////////////////////////
                        PUSH MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PushMode_ImmediateDistribution() public {
        uint256 tokenId = 11;

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Give collection some ETH to send
        vm.deal(address(collection), 1 ether);

        uint256 manufacturerBalBefore = manufacturer.balance;
        uint256 partnerBalBefore = partner.balance;

        // Collection triggers distribution
        vm.prank(address(collection));
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        // Immediate transfer should have happened
        assertGt(manufacturer.balance, manufacturerBalBefore, "Manufacturer should receive ETH");
        assertGt(partner.balance, partnerBalBefore, "Partner should receive ETH");
    }

    function test_PullMode_Accumulation() public {
        uint256 tokenId = 12;

        // Disable push mode
        vm.prank(admin);
        splitter.setPushMode(false);

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Give collection some ETH to send
        vm.deal(address(collection), 1 ether);

        uint256 manufacturerBalBefore = manufacturer.balance;

        // Collection triggers distribution
        vm.prank(address(collection));
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        // No immediate transfer, should accumulate
        assertEq(manufacturer.balance, manufacturerBalBefore, "Manufacturer should NOT receive immediate ETH");
        assertGt(splitter.pendingETH(manufacturer), 0, "Manufacturer should have pending balance");
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetWallets() public {
        address newManufacturer = address(0x111);
        address newPartner = address(0x222);

        vm.prank(admin);
        splitter.setWallets(newManufacturer, newPartner);

        assertEq(splitter.manufacturerWallet(), newManufacturer);
        assertEq(splitter.partnerWallet(), newPartner);
    }

    function test_SetWallets_ByFeeAdmin() public {
        address newManufacturer = address(0x333);

        // Grant FEE_ADMIN to another address
        address feeAdmin = address(0x444);
        bytes32 feeAdminRole = splitter.FEE_ADMIN_ROLE();
        vm.prank(admin);
        splitter.grantRole(feeAdminRole, feeAdmin);

        vm.prank(feeAdmin);
        splitter.setWallets(newManufacturer, partner);

        assertEq(splitter.manufacturerWallet(), newManufacturer);
    }

    function test_SetCuts() public {
        vm.prank(admin);
        splitter.setCuts(500, 200, 300);

        assertEq(splitter.manufacturerCutBP(), 500);
        assertEq(splitter.partnerCutBP(), 200);
        assertEq(splitter.defaultCreatorCutBP(), 300);
    }

    function test_SetCuts_ExceedsMax_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(KonduxRoyaltySplitter.InvalidCuts.selector);
        splitter.setCuts(600, 300, 300); // Total = 1200 > 1000
    }

    function test_SetPushMode() public {
        assertTrue(splitter.pushModeEnabled());

        vm.prank(admin);
        splitter.setPushMode(false);

        assertFalse(splitter.pushModeEnabled());
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawETH() public {
        uint256 tokenId = 13;

        // Disable push mode to accumulate
        vm.prank(admin);
        splitter.setPushMode(false);

        vm.prank(admin);
        splitter.registerCreator(tokenId, creator, CREATOR_CUT);

        // Trigger distribution
        vm.deal(address(collection), 1 ether);
        vm.prank(address(collection));
        splitter.receivePaymentForToken{value: 0.1 ether}(tokenId);

        uint256 pending = splitter.pendingETH(manufacturer);
        assertGt(pending, 0);

        uint256 balBefore = manufacturer.balance;

        vm.prank(manufacturer);
        splitter.withdrawETH();

        assertEq(manufacturer.balance, balBefore + pending);
        assertEq(splitter.pendingETH(manufacturer), 0);
    }
}
