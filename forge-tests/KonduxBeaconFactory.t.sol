// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxRoyaltySplitter.sol";

contract KonduxBeaconFactoryTest is Test {
    KonduxBeaconFactory factory;
    KonduxImplementation impl;
    
    address deployer = address(0x1);
    address user = address(0x2);
    address otherUser = address(0x3);
    address partnerWallet = address(0x4);
    address defaultCreatorWallet = address(0x5);
    
    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);
        
        vm.startPrank(deployer);
        impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));
        vm.stopPrank();
    }

    function test_DeployClone_Public() public {
        vm.startPrank(user);

        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,uint256,address,address,address)",
            "Test", "TST",
            1000,
            user, // Initial Admin
            address(factory), // Factory for security config
            address(0) // No splitter
        );

        address cloneAddress = factory.deployClone(initData);
        KonduxImplementation clone = KonduxImplementation(payable(cloneAddress));

        // Check ownership/roles
        bool userIsAdmin = clone.hasRole(clone.DEFAULT_ADMIN_ROLE(), user);
        bool factoryIsAdmin = clone.hasRole(clone.DEFAULT_ADMIN_ROLE(), address(factory));

        assertTrue(userIsAdmin, "User should be admin");
        assertTrue(factoryIsAdmin, "Factory should be admin for security config");

        // Check royaltyInfo returns user (no splitter)
        (address receiver, uint256 royaltyAmount) = clone.royaltyInfo(1, 10000);
        assertEq(receiver, user, "Royalty receiver should be user (no splitter)");
        assertEq(royaltyAmount, 1000, "Royalty should be 10%");

        vm.stopPrank();
    }

    function test_DeployClone_Restricted() public {
        vm.startPrank(deployer);
        factory.setPublicDeployment(false);
        vm.stopPrank();

        vm.startPrank(user);
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,uint256,address,address,address)",
            "Test", "TST",
            1000,
            user,
            address(factory),
            address(0)
        );

        vm.expectRevert(); // Should revert because user doesn't have CLONE_DEPLOYER_ROLE
        factory.deployClone(initData);
        vm.stopPrank();

        // Grant role and try again
        vm.startPrank(deployer);
        factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), user);
        vm.stopPrank();

        vm.startPrank(user);
        factory.deployClone(initData);
        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_RoyaltyInfoReturnsCorrectReceiver() public {
        vm.startPrank(user);

        // Deploy clone with splitter
        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test Collection",  // name
            "TCOL",             // symbol
            1000,               // maxSupply
            user,               // initialAdmin
            true,               // deploySplitter
            partnerWallet,      // partnerWallet
            500,                // manufacturerCutBP (5%)
            0,                  // partnerCutBP (0%)
            500,                // defaultCreatorCutBP (5%)
            defaultCreatorWallet // defaultCreatorWallet
        );

        KonduxImplementation clone = KonduxImplementation(payable(cloneAddress));

        // Verify splitter was deployed
        assertTrue(splitterAddress != address(0), "Splitter should be deployed");

        // Verify clone's royaltySplitter storage is set
        assertEq(clone.royaltySplitter(), splitterAddress, "Clone's royaltySplitter should be set");

        // KEY TEST: Verify royaltyInfo returns the SPLITTER address, not the admin
        (address receiver, uint256 royaltyAmount) = clone.royaltyInfo(1, 10000);
        assertEq(receiver, splitterAddress, "Royalty receiver should be the splitter contract");
        assertEq(royaltyAmount, 1000, "Royalty should be 10% (500+0+500 BP)");

        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_SplitterLinkedToCollection() public {
        vm.startPrank(user);

        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test Collection",
            "TCOL",
            1000,
            user,
            true,
            partnerWallet,
            500,
            0,
            500,
            defaultCreatorWallet
        );

        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddress));

        // Verify splitter's collection is set to the clone
        assertEq(splitter.collection(), cloneAddress, "Splitter's collection should be the clone");

        // Verify splitter has COLLECTION_ROLE granted to clone
        assertTrue(
            splitter.hasRole(splitter.COLLECTION_ROLE(), cloneAddress),
            "Clone should have COLLECTION_ROLE on splitter"
        );

        // Verify factory mapping
        assertEq(
            factory.collectionToSplitter(cloneAddress),
            splitterAddress,
            "Factory should map collection to splitter"
        );

        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_NoSplitterOption() public {
        vm.startPrank(user);

        // Deploy clone WITHOUT splitter (deploySplitter = false)
        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test Collection",
            "TCOL",
            1000,
            user,
            false,              // deploySplitter = false
            address(0),
            0,
            0,
            0,
            address(0)
        );

        KonduxImplementation clone = KonduxImplementation(payable(cloneAddress));

        // Verify no splitter was deployed
        assertEq(splitterAddress, address(0), "Splitter should not be deployed");

        // Verify clone's royaltySplitter is zero
        assertEq(clone.royaltySplitter(), address(0), "Clone's royaltySplitter should be zero");

        // Verify royaltyInfo returns the admin (user), not a splitter
        (address receiver,) = clone.royaltyInfo(1, 10000);
        assertEq(receiver, user, "Royalty receiver should be the admin when no splitter");

        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_SplitterConfigCorrect() public {
        vm.startPrank(user);

        uint96 manufacturerCut = 400;  // 4%
        uint96 partnerCut = 300;       // 3%
        uint96 creatorCut = 300;       // 3%

        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test Collection",
            "TCOL",
            1000,
            user,               // initialAdmin = manufacturerWallet
            true,
            partnerWallet,
            manufacturerCut,
            partnerCut,
            creatorCut,
            defaultCreatorWallet
        );

        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddress));

        // Verify splitter configuration
        assertEq(splitter.manufacturerWallet(), user, "Manufacturer wallet should be initialAdmin");
        assertEq(splitter.partnerWallet(), partnerWallet, "Partner wallet should match");
        assertEq(splitter.manufacturerCutBP(), manufacturerCut, "Manufacturer cut should match");
        assertEq(splitter.partnerCutBP(), partnerCut, "Partner cut should match");
        assertEq(splitter.defaultCreatorCutBP(), creatorCut, "Creator cut should match");
        assertEq(splitter.defaultCreatorWallet(), defaultCreatorWallet, "Default creator wallet should match");

        // Verify total royalty on clone matches sum of cuts
        (address receiver, uint256 royaltyAmount) = KonduxImplementation(payable(cloneAddress)).royaltyInfo(1, 10000);
        assertEq(receiver, splitterAddress, "Receiver should be splitter");
        assertEq(royaltyAmount, manufacturerCut + partnerCut + creatorCut, "Royalty should be sum of cuts");

        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_MintingRegistersCreator() public {
        vm.startPrank(user);

        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test Collection",
            "TCOL",
            1000,
            user,
            true,
            partnerWallet,
            500,
            0,
            500,
            defaultCreatorWallet
        );

        KonduxImplementation clone = KonduxImplementation(payable(cloneAddress));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddress));

        // Mint a token - should auto-register recipient as creator
        address minter = address(0x123);
        uint256 tokenId = clone.safeMint(minter, 12345);

        // Verify creator was registered in splitter
        (address creator, uint96 creatorCutBP) = splitter.getCreatorInfo(tokenId);
        assertEq(creator, minter, "Creator should be the mint recipient");
        assertEq(creatorCutBP, 500, "Creator cut should match collection default");

        vm.stopPrank();
    }

    function test_DeployCloneWithSplitter_Restricted() public {
        vm.startPrank(deployer);
        factory.setPublicDeployment(false);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(); // Should revert - no CLONE_DEPLOYER_ROLE
        factory.deployCloneWithSplitter(
            "Test",
            "TST",
            1000,
            user,
            true,
            partnerWallet,
            500,
            0,
            500,
            defaultCreatorWallet
        );
        vm.stopPrank();

        // Grant role and try again
        vm.startPrank(deployer);
        factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), user);
        vm.stopPrank();

        vm.startPrank(user);
        (address cloneAddress, address splitterAddress) = factory.deployCloneWithSplitter(
            "Test",
            "TST",
            1000,
            user,
            true,
            partnerWallet,
            500,
            0,
            500,
            defaultCreatorWallet
        );
        assertTrue(cloneAddress != address(0), "Clone should be deployed");
        assertTrue(splitterAddress != address(0), "Splitter should be deployed");
        vm.stopPrank();
    }
}
