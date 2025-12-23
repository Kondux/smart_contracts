// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../contracts/Minter_Bundle.sol";
import "./utils/MockTreasury.sol";
import "./utils/MockKondux.sol";

/**
 * @title MinterBundle Tests
 * @notice Forge tests for the MinterBundle contract - bundle minting with ETH, kBox, and founders pass
 * @dev Migrated from test/minter_bundle.test.ts
 */
contract MinterBundleTest is Test {
    MinterBundle public minter;
    MockKondux public kNFT;
    MockKondux public kBox;
    MockKondux public foundersPass;
    MockTreasury public treasury;

    address public admin;
    address public user;
    address public user2;

    uint256 public constant DEFAULT_PRICE = 0.25 ether;
    uint16 public constant DEFAULT_BUNDLE_SIZE = 5;

    event BundleMinted(address indexed minter, uint256[] tokenIds);
    event FoundersPassUsed(address indexed minter, uint256[] tokenIds, uint256 foundersPassId);
    event TreasuryChanged(address indexed treasury);
    event KNFTChanged(address indexed kNFT);
    event KBoxChanged(address indexed kBox);
    event FoundersPassChanged(address indexed foundersPass);
    event PriceChanged(uint256 price);
    event BundleSizeChanged(uint16 bundleSize);
    event Paused(bool paused);
    event PublicMintActive(bool active);
    event KBoxMintActive(bool active);
    event FoundersPassMintActive(bool active);
    event WhitelistActive(bool active);
    event WhitelistRootChanged(bytes32 root);

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        user2 = makeAddr("user2");

        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);

        vm.startPrank(admin);
        
        // Deploy mock contracts with 8-param constructor for compatibility
        kNFT = new MockKondux("Kondux NFT", "KNFT", address(0), address(0), address(0), address(0), address(0), 10000);
        kBox = new MockKondux("Kondux kBox", "KBOX", address(0), address(0), address(0), address(0), address(0), 10000);
        foundersPass = new MockKondux("Founders Pass", "FP", address(0), address(0), address(0), address(0), address(0), 10000);
        treasury = new MockTreasury();

        // Deploy MinterBundle
        minter = new MinterBundle(
            address(kNFT),
            address(kBox),
            address(foundersPass),
            address(treasury)
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(minter.price(), DEFAULT_PRICE, "Default price should be 0.25 ETH");
        assertEq(minter.bundleSize(), DEFAULT_BUNDLE_SIZE, "Default bundle size should be 5");
        assertTrue(minter.paused(), "Should be paused by default");
        assertTrue(minter.foundersPassActive(), "Founders pass should be active by default");
        assertTrue(minter.kBoxActive(), "kBox should be active by default");
        assertTrue(minter.whitelistActive(), "Whitelist should be active by default");
        assertFalse(minter.kNFTActive(), "Public mint should be inactive by default");
        assertEq(minter.getKNFT(), address(kNFT), "kNFT should be set");
        assertEq(minter.getKBox(), address(kBox), "kBox should be set");
        assertEq(minter.getTreasury(), address(treasury), "Treasury should be set");
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC MINT (ETH)
    //////////////////////////////////////////////////////////////*/

    function test_publicMint_withETH() public {
        // Setup: unpause and activate public mint
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        // User mints with ETH
        vm.prank(user);
        uint256[] memory tokenIds = minter.publicMint{value: DEFAULT_PRICE}();

        // Verify 5 NFTs minted
        assertEq(tokenIds.length, DEFAULT_BUNDLE_SIZE, "Should mint bundle size tokens");
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
        
        for (uint256 i = 0; i < DEFAULT_BUNDLE_SIZE; i++) {
            assertEq(kNFT.ownerOf(i), user, "User should own each token");
        }

        // Verify ETH sent to treasury
        assertEq(address(treasury).balance, DEFAULT_PRICE, "Treasury should receive ETH");
    }

    function test_publicMint_revertsWithInsufficientETH() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert("Not enough ETH sent");
        minter.publicMint{value: 0}();

        vm.prank(user);
        vm.expectRevert("Not enough ETH sent");
        minter.publicMint{value: 0.00001 ether}();
    }

    function test_publicMint_excessETHStillMintsSameBundleSize() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        // Mint with excess ETH
        vm.prank(user);
        minter.publicMint{value: 2.5 ether}();

        // Should still only get bundleSize NFTs
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have exactly 5 NFTs");
    }

    function test_publicMint_revertsWhenPaused() public {
        vm.prank(admin);
        minter.setPublicMintActive(true);
        // Contract is paused by default

        vm.prank(user);
        vm.expectRevert("Contract is paused");
        minter.publicMint{value: DEFAULT_PRICE}();
    }

    function test_publicMint_allowedWithFoundersPassWhenPublicInactive() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        // kNFTActive is false by default, foundersPassActive is true
        vm.stopPrank();

        // Give user a founders pass
        vm.prank(user);
        foundersPass.faucet();
        assertEq(foundersPass.balanceOf(user), 1, "User should have a founders pass");

        // User can mint because they have a founders pass
        vm.prank(user);
        minter.publicMint{value: DEFAULT_PRICE}();
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
    }

    function test_publicMint_revertsWithoutFoundersPassWhenPublicInactive() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        // kNFTActive is false by default, foundersPassActive is true
        vm.stopPrank();

        // User has no founders pass
        vm.prank(user);
        vm.expectRevert("kNFT minting is not active or you don't have a Founder's Pass");
        minter.publicMint{value: DEFAULT_PRICE}();
    }

    /*//////////////////////////////////////////////////////////////
                        MINT WITH KBOX (BURN)
    //////////////////////////////////////////////////////////////*/

    function test_publicMintWithBox() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a kBox (faucet mints tokenId 0)
        vm.prank(user);
        kBox.faucet();
        
        uint256 kBoxTokenId = 0;
        assertEq(kBox.balanceOf(user), 1, "User should have 1 kBox");
        assertEq(kBox.ownerOf(kBoxTokenId), user, "User should own kBox");

        // Approve minter to burn kBox
        vm.prank(user);
        kBox.approve(address(minter), kBoxTokenId);

        // Mint with kBox
        vm.prank(user);
        minter.publicMintWithBox(kBoxTokenId);

        // Verify kBox burned and NFTs minted
        assertEq(kBox.balanceOf(user), 0, "kBox should be burned");
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
    }

    function test_publicMintWithBox_revertsWithoutApproval() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a kBox
        vm.prank(user);
        kBox.faucet();

        // Try to mint without approval
        vm.prank(user);
        vm.expectRevert("This contract is not approved to burn this kBox");
        minter.publicMintWithBox(0);
    }

    function test_publicMintWithBox_revertsIfNotOwner() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a kBox
        vm.prank(user);
        kBox.faucet();

        // User2 tries to use user's kBox
        vm.prank(user2);
        vm.expectRevert("You are not the owner of this kBox");
        minter.publicMintWithBox(0);
    }

    function test_publicMintWithBox_revertsWhenKBoxMintInactive() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setKBoxMintActive(false);
        vm.stopPrank();

        // Give user a kBox and approve
        vm.startPrank(user);
        kBox.faucet();
        kBox.approve(address(minter), 0);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert("kBox minting is not active");
        minter.publicMintWithBox(0);
    }

    /*//////////////////////////////////////////////////////////////
                    MINT WITH FOUNDERS PASS
    //////////////////////////////////////////////////////////////*/

    function test_publicMintWithFoundersPass() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a founders pass (faucet mints tokenId 0)
        vm.prank(user);
        foundersPass.faucet();
        
        uint256 foundersPassId = 0;
        assertEq(foundersPass.balanceOf(user), 1, "User should have 1 founders pass");

        // Mint with founders pass
        vm.prank(user);
        minter.publicMintWithFoundersPass(foundersPassId);

        // Verify NFTs minted and founders pass marked as used
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
        assertTrue(minter.usedFoundersPass(foundersPassId), "Founders pass should be marked used");
    }

    function test_publicMintWithFoundersPass_cannotReusePass() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a founders pass
        vm.prank(user);
        foundersPass.faucet();

        // First mint succeeds
        vm.prank(user);
        minter.publicMintWithFoundersPass(0);

        // Second mint with same pass fails
        vm.prank(user);
        vm.expectRevert("This founders pass has already been used");
        minter.publicMintWithFoundersPass(0);
    }

    function test_publicMintWithFoundersPass_revertsIfNotOwner() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        // Give user a founders pass
        vm.prank(user);
        foundersPass.faucet();

        // User2 tries to use user's founders pass
        vm.prank(user2);
        vm.expectRevert("You are not the owner of this founders pass");
        minter.publicMintWithFoundersPass(0);
    }

    function test_publicMintWithFoundersPass_revertsWhenInactive() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setFoundersPassMintActive(false);
        vm.stopPrank();

        // Give user a founders pass
        vm.prank(user);
        foundersPass.faucet();

        vm.prank(user);
        vm.expectRevert("Founder's Pass minting is not active");
        minter.publicMintWithFoundersPass(0);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST MINT
    //////////////////////////////////////////////////////////////*/

    function test_publicMintWhitelist() public {
        // Create a merkle tree with user address
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf; // Single leaf tree, root = leaf

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setWhitelistRoot(root);
        vm.stopPrank();

        // Create proof (empty for single leaf)
        bytes32[] memory proof = new bytes32[](0);

        // User mints with whitelist
        vm.prank(user);
        minter.publicMintWhitelist{value: DEFAULT_PRICE}(proof);

        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
    }

    function test_publicMintWhitelist_withMerkleTree() public {
        // Create a merkle tree with two leaves
        bytes32 leaf1 = keccak256(abi.encodePacked(user));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));
        
        // Root is hash of both leaves (sorted for consistency)
        bytes32 root;
        if (uint256(leaf1) < uint256(leaf2)) {
            root = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            root = keccak256(abi.encodePacked(leaf2, leaf1));
        }

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setWhitelistRoot(root);
        vm.stopPrank();

        // Create proof for user (need leaf2 as sibling)
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        // User mints with whitelist
        vm.prank(user);
        minter.publicMintWhitelist{value: DEFAULT_PRICE}(proof);

        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
    }

    function test_publicMintWhitelist_revertsWithInvalidProof() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setWhitelistRoot(root);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        // User2 tries to use user's proof
        vm.prank(user2);
        vm.expectRevert("Incorrect proof");
        minter.publicMintWhitelist{value: DEFAULT_PRICE}(proof);
    }

    function test_publicMintWhitelist_revertsWhenWhitelistInactive() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setWhitelistRoot(root);
        minter.setWhitelistActive(false);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Whitelist is not active");
        minter.publicMintWhitelist{value: DEFAULT_PRICE}(proof);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setPrice() public {
        uint256 newPrice = 0.5 ether;

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        
        vm.expectEmit(true, true, true, true);
        emit PriceChanged(newPrice);
        minter.setPrice(newPrice);
        vm.stopPrank();

        assertEq(minter.price(), newPrice, "Price should be updated");

        // Old price should fail
        vm.prank(user);
        vm.expectRevert("Not enough ETH sent");
        minter.publicMint{value: 0.25 ether}();

        // New price should work
        vm.prank(user);
        minter.publicMint{value: newPrice}();
        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "User should have 5 NFTs");
    }

    function test_setPrice_revertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert("Price must be greater than 0");
        minter.setPrice(0);
    }

    function test_setPrice_revertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setPrice(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        BUNDLE SIZE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setBundleSize() public {
        uint16 newBundleSize = 10;

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        minter.setPrice(0.5 ether); // Update price for larger bundle
        
        vm.expectEmit(true, true, true, true);
        emit BundleSizeChanged(newBundleSize);
        minter.setBundleSize(newBundleSize);
        vm.stopPrank();

        assertEq(minter.bundleSize(), newBundleSize, "Bundle size should be updated");

        vm.prank(user);
        minter.publicMint{value: 0.5 ether}();
        assertEq(kNFT.balanceOf(user), newBundleSize, "User should have 10 NFTs");
    }

    function test_setBundleSize_revertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert("Bundle size must be greater than 0");
        minter.setBundleSize(0);
    }

    function test_setBundleSize_revertsOnTooLarge() public {
        vm.prank(admin);
        vm.expectRevert("Bundle size must be less than or equal to 15");
        minter.setBundleSize(16);
    }

    function test_setBundleSize_revertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setBundleSize(10);
    }

    /*//////////////////////////////////////////////////////////////
                        ADDRESS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setTreasury() public {
        MockTreasury newTreasury = new MockTreasury();

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryChanged(address(newTreasury));
        minter.setTreasury(address(newTreasury));

        assertEq(minter.getTreasury(), address(newTreasury), "Treasury should be updated");

        // Verify new treasury receives ETH
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        vm.prank(user);
        minter.publicMint{value: DEFAULT_PRICE}();

        assertEq(address(newTreasury).balance, DEFAULT_PRICE, "New treasury should receive ETH");
    }

    function test_setTreasury_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Treasury address is not set");
        minter.setTreasury(address(0));
    }

    function test_setKNFT() public {
        MockKondux newKNFT = new MockKondux("New KNFT", "NKNFT", address(0), address(0), address(0), address(0), address(0), 10000);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit KNFTChanged(address(newKNFT));
        minter.setKNFT(address(newKNFT));

        assertEq(minter.getKNFT(), address(newKNFT), "kNFT should be updated");

        // Verify new kNFT receives mints
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        vm.prank(user);
        minter.publicMint{value: DEFAULT_PRICE}();

        assertEq(newKNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "New kNFT should receive mints");
        assertEq(kNFT.balanceOf(user), 0, "Old kNFT should not receive mints");
    }

    function test_setKNFT_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("KNFT address is not set");
        minter.setKNFT(address(0));
    }

    function test_setKBox() public {
        MockKondux newKBox = new MockKondux("New kBox", "NKBOX", address(0), address(0), address(0), address(0), address(0), 10000);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit KBoxChanged(address(newKBox));
        minter.setKBox(address(newKBox));

        assertEq(minter.getKBox(), address(newKBox), "kBox should be updated");
    }

    function test_setKBox_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("kBox address is not set");
        minter.setKBox(address(0));
    }

    function test_setFoundersPass() public {
        MockKondux newFoundersPass = new MockKondux("New FP", "NFP", address(0), address(0), address(0), address(0), address(0), 10000);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit FoundersPassChanged(address(newFoundersPass));
        minter.setFoundersPass(address(newFoundersPass));
    }

    function test_setFoundersPass_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Founders pass address is not set");
        minter.setFoundersPass(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setPaused() public {
        assertTrue(minter.paused(), "Should be paused by default");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Paused(false);
        minter.setPaused(false);

        assertFalse(minter.paused(), "Should be unpaused");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Paused(true);
        minter.setPaused(true);

        assertTrue(minter.paused(), "Should be paused again");
    }

    function test_setPaused_revertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setPaused(false);
    }

    function test_setPublicMintActive() public {
        assertFalse(minter.kNFTActive(), "Public mint should be inactive by default");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit PublicMintActive(true);
        minter.setPublicMintActive(true);

        assertTrue(minter.kNFTActive(), "Public mint should be active");
    }

    function test_setKBoxMintActive() public {
        assertTrue(minter.kBoxActive(), "kBox mint should be active by default");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit KBoxMintActive(false);
        minter.setKBoxMintActive(false);

        assertFalse(minter.kBoxActive(), "kBox mint should be inactive");
    }

    function test_setFoundersPassMintActive() public {
        assertTrue(minter.foundersPassActive(), "Founders pass mint should be active by default");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit FoundersPassMintActive(false);
        minter.setFoundersPassMintActive(false);

        assertFalse(minter.foundersPassActive(), "Founders pass mint should be inactive");
    }

    function test_setWhitelistActive() public {
        assertTrue(minter.whitelistActive(), "Whitelist should be active by default");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit WhitelistActive(false);
        minter.setWhitelistActive(false);

        assertFalse(minter.whitelistActive(), "Whitelist should be inactive");
    }

    function test_setWhitelistRoot() public {
        bytes32 newRoot = keccak256("newRoot");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit WhitelistRootChanged(newRoot);
        minter.setWhitelistRoot(newRoot);

        assertEq(minter.rootWhitelist(), newRoot, "Whitelist root should be updated");
    }

    function test_setWhitelistRoot_revertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setWhitelistRoot(keccak256("test"));
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_setAdmin() public {
        vm.prank(admin);
        minter.setAdmin(user);

        // User should now be able to admin functions
        vm.prank(user);
        minter.setPaused(false);
        assertFalse(minter.paused(), "User should be able to unpause");
    }

    function test_setAdmin_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Admin address is not set");
        minter.setAdmin(address(0));
    }

    function test_setAdmin_revertsIfAlreadyAdmin() public {
        vm.prank(admin);
        minter.setAdmin(user);

        vm.prank(admin);
        vm.expectRevert("Address already has admin role");
        minter.setAdmin(user);
    }

    function test_setAdmin_revertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setAdmin(user2);
    }

    /*//////////////////////////////////////////////////////////////
                        DNA OPERATIONS (VIA KNFT)
    //////////////////////////////////////////////////////////////*/

    function test_dnaSetAfterMint() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        vm.prank(user);
        minter.publicMint{value: DEFAULT_PRICE}();

        // Initially DNA should be 0
        for (uint256 i = 0; i < DEFAULT_BUNDLE_SIZE; i++) {
            assertEq(kNFT.getDna(i), 0, "Initial DNA should be 0");
        }

        // Set DNA for first token
        uint256 newDna = uint256(keccak256("NEW"));
        kNFT.setDna(0, newDna);

        assertEq(kNFT.getDna(0), newDna, "DNA should be updated");
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    function test_emitsBundleMintedEvent() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        vm.stopPrank();

        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        uint256[] memory expectedIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            expectedIds[i] = i;
        }
        emit BundleMinted(user, expectedIds);
        minter.publicMint{value: DEFAULT_PRICE}();
    }

    function test_emitsFoundersPassUsedEvent() public {
        vm.startPrank(admin);
        minter.setPaused(false);
        vm.stopPrank();

        vm.prank(user);
        foundersPass.faucet();

        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        uint256[] memory expectedIds = new uint256[](5);
        emit FoundersPassUsed(user, expectedIds, 0);
        minter.publicMintWithFoundersPass(0);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_publicMint_variablePrices(uint256 price) public {
        // Bound price to reasonable range
        price = bound(price, 0.01 ether, 10 ether);

        vm.startPrank(admin);
        minter.setPaused(false);
        minter.setPublicMintActive(true);
        minter.setPrice(price);
        vm.stopPrank();

        vm.prank(user);
        minter.publicMint{value: price}();

        assertEq(kNFT.balanceOf(user), DEFAULT_BUNDLE_SIZE, "Should mint correct number of NFTs");
        assertEq(address(treasury).balance, price, "Treasury should receive exact price");
    }

    function testFuzz_setBundleSize(uint16 size) public {
        // Bound to valid range
        size = uint16(bound(size, 1, 15));

        vm.prank(admin);
        minter.setBundleSize(size);

        assertEq(minter.bundleSize(), size, "Bundle size should be set correctly");
    }
}
