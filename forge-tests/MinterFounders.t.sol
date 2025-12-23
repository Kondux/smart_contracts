// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../contracts/Minter_Founders.sol";
import "../contracts/Authority.sol";
import "../contracts/Treasury.sol";
import "./utils/MockKondux.sol";
import "./utils/MockKonduxFounders.sol";

/**
 * @title MinterFounders Tests
 * @notice Forge tests for the MinterFounders contract - whitelist minting with Merkle proofs
 * @dev Migrated from test/minter_founders.test.ts
 */
contract MinterFoundersTest is Test {
    MinterFounders public minterFounders;
    Authority public authority;
    Treasury public treasury;
    MockKonduxFounders public konduxFounders;
    MockKondux public kondux;

    address public owner;
    address public user;
    address public user2;

    // Constants for testing
    uint256 public constant PRICE_020 = 0.2 ether;
    uint256 public constant PRICE_025 = 0.25 ether;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");

        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);

        vm.startPrank(owner);

        // Deploy Authority with owner as all roles
        authority = new Authority(owner, owner, owner, owner);

        // Deploy Treasury with authority
        treasury = new Treasury(address(authority));

        // Deploy mock NFT contracts
        konduxFounders = new MockKonduxFounders("Kondux Founders NFT", "fKDX");
        kondux = new MockKondux("Kondux", "KDX", address(0), address(0), address(0), address(0), address(0), 10000);

        // Deploy MinterFounders
        minterFounders = new MinterFounders(
            address(authority),
            address(konduxFounders),
            address(kondux),
            address(treasury)
        );

        // Grant MINTER_ROLE to minterFounders via Authority
        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        authority.pushRole(address(minterFounders), MINTER_ROLE);

        // Set kondux MINTER_ROLE (for MockKondux, we need a different approach)
        // For the real Kondux contract, you'd call kondux.setRole()
        
        // Grant treasury permissions
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(minterFounders), true);
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, owner, true);

        // Set prices
        minterFounders.setPriceFounders020(PRICE_020);
        minterFounders.setPriceFounders025(PRICE_025);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(minterFounders.priceFounders020(), PRICE_020, "Price 020 should be set");
        assertEq(minterFounders.priceFounders025(), PRICE_025, "Price 025 should be set");
        assertFalse(minterFounders.pausedFounders020(), "020 minting should not be paused");
        assertFalse(minterFounders.pausedFounders025(), "025 minting should not be paused");
        assertFalse(minterFounders.pausedFreeFounders(), "Free founders minting should not be paused");
        assertFalse(minterFounders.pausedFreeKNFT(), "Free KNFT minting should not be paused");
    }

    /*//////////////////////////////////////////////////////////////
                    WHITELIST MINT FOUNDERS 020
    //////////////////////////////////////////////////////////////*/

    function test_whitelistMintFounders020() public {
        // Create merkle tree with user address
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf; // Single leaf tree

        // Set root
        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        assertEq(minterFounders.rootFounders020(), root, "Root should be set");

        // Create proof (empty for single leaf)
        bytes32[] memory proof = new bytes32[](0);

        // Initial supply should be 0
        assertEq(konduxFounders.totalSupply(), 0, "Initial supply should be 0");

        // User mints with whitelist
        vm.prank(user);
        uint256 tokenId = minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        // Verify mint
        assertEq(konduxFounders.totalSupply(), 1, "Supply should be 1");
        assertEq(konduxFounders.balanceOf(user), 1, "User should have 1 NFT");
        assertEq(konduxFounders.ownerOf(tokenId), user, "User should own the token");

        // Verify claim is tracked
        assertTrue(minterFounders.founders020Claimed(user), "User should be marked as claimed");
    }

    function test_whitelistMintFounders020_revertsWithInsufficientEther() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Not enought ether");
        minterFounders.whitelistMintFounders020{value: 0.1 ether}(proof);
    }

    function test_whitelistMintFounders020_revertsOnDoubleClaim() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        // First mint
        vm.prank(user);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        // Second mint should fail
        vm.prank(user);
        vm.expectRevert("Already claimed");
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);
    }

    function test_whitelistMintFounders020_revertsWithInvalidProof() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        // User2 tries with user's proof/root
        vm.prank(user2);
        vm.expectRevert("Incorrect proof");
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);
    }

    function test_whitelistMintFounders020_depositsToTreasury() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        uint256 treasuryBalanceBefore = address(treasury).balance;

        vm.prank(user);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        assertEq(address(treasury).balance - treasuryBalanceBefore, PRICE_020, "Treasury should receive ETH");
    }

    /*//////////////////////////////////////////////////////////////
                    WHITELIST MINT FOUNDERS 025
    //////////////////////////////////////////////////////////////*/

    function test_whitelistMintFounders025() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders025(root);

        assertEq(minterFounders.rootFounders025(), root, "Root should be set");

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        uint256 tokenId = minterFounders.whitelistMintFounders025{value: PRICE_025}(proof);

        assertEq(konduxFounders.totalSupply(), 1, "Supply should be 1");
        assertEq(konduxFounders.balanceOf(user), 1, "User should have 1 NFT");
        assertEq(konduxFounders.ownerOf(tokenId), user, "User should own the token");
        assertTrue(minterFounders.founders025Claimed(user), "User should be marked as claimed");
    }

    function test_whitelistMintFounders025_revertsWithInsufficientEther() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders025(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Not enought ether");
        minterFounders.whitelistMintFounders025{value: 0.2 ether}(proof);
    }

    function test_whitelistMintFounders025_revertsOnDoubleClaim() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders025(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        minterFounders.whitelistMintFounders025{value: PRICE_025}(proof);

        vm.prank(user);
        vm.expectRevert("Already claimed");
        minterFounders.whitelistMintFounders025{value: PRICE_025}(proof);
    }

    /*//////////////////////////////////////////////////////////////
                        FREE KNFT MINT
    //////////////////////////////////////////////////////////////*/

    function test_whitelistMintFreeKNFT() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeKNFT(root);

        assertEq(minterFounders.rootFreeKNFT(), root, "Root should be set");

        bytes32[] memory proof = new bytes32[](0);

        assertEq(kondux.totalSupply(), 0, "Initial supply should be 0");

        vm.prank(user);
        uint256 tokenId = minterFounders.whitelistMintFreeKNFT(proof);

        assertEq(kondux.totalSupply(), 1, "Supply should be 1");
        assertEq(kondux.balanceOf(user), 1, "User should have 1 NFT");
        assertTrue(minterFounders.freeKNFTClaimed(user), "User should be marked as claimed");
    }

    function test_whitelistMintFreeKNFT_revertsOnDoubleClaim() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeKNFT(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        minterFounders.whitelistMintFreeKNFT(proof);

        vm.prank(user);
        vm.expectRevert("Already claimed");
        minterFounders.whitelistMintFreeKNFT(proof);
    }

    function test_whitelistMintFreeKNFT_revertsWithInvalidProof() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeKNFT(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user2);
        vm.expectRevert("Incorrect proof");
        minterFounders.whitelistMintFreeKNFT(proof);
    }

    /*//////////////////////////////////////////////////////////////
                    FREE FOUNDERS MINT
    //////////////////////////////////////////////////////////////*/

    function test_whitelistMintFreeFounders() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeFounders(root);

        assertEq(minterFounders.rootFreeFounders(), root, "Root should be set");

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        uint256 tokenId = minterFounders.whitelistMintFreeFounders(proof);

        assertEq(konduxFounders.totalSupply(), 1, "Supply should be 1");
        assertEq(konduxFounders.balanceOf(user), 1, "User should have 1 NFT");
        assertTrue(minterFounders.freeFoundersClaimed(user), "User should be marked as claimed");
    }

    function test_whitelistMintFreeFounders_revertsOnDoubleClaim() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeFounders(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        minterFounders.whitelistMintFreeFounders(proof);

        vm.prank(user);
        vm.expectRevert("Already claimed");
        minterFounders.whitelistMintFreeFounders(proof);
    }

    /*//////////////////////////////////////////////////////////////
                        MERKLE PROOF TESTS
    //////////////////////////////////////////////////////////////*/

    function test_merkleProof_twoLeafTree() public {
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

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        // Create proof for user (need leaf2 as sibling)
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        // User mints with whitelist
        vm.prank(user);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        assertEq(konduxFounders.balanceOf(user), 1, "User should have 1 NFT");

        // User2 should also be able to mint with correct proof
        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = leaf1;

        vm.prank(user2);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof2);

        assertEq(konduxFounders.balanceOf(user2), 1, "User2 should have 1 NFT");
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE CONTROLS
    //////////////////////////////////////////////////////////////*/

    function test_pausedFounders020() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(owner);
        minterFounders.setRootFounders020(root);
        minterFounders.setPausedFounders020(true);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Founders 020 minting is paused");
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);
    }

    function test_pausedFounders025() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(owner);
        minterFounders.setRootFounders025(root);
        minterFounders.setPausedFounders025(true);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Founders 025 minting is paused");
        minterFounders.whitelistMintFounders025{value: PRICE_025}(proof);
    }

    function test_pausedFreeFounders() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(owner);
        minterFounders.setRootFreeFounders(root);
        minterFounders.setPausedFreeFounders(true);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Free Founders minting is paused");
        minterFounders.whitelistMintFreeFounders(proof);
    }

    function test_pausedFreeKNFT() public {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(owner);
        minterFounders.setRootFreeKNFT(root);
        minterFounders.setPausedFreeKNFT(true);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert("Free KNFT minting is paused");
        minterFounders.whitelistMintFreeKNFT(proof);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setPriceFounders020() public {
        uint256 newPrice = 0.3 ether;

        vm.prank(owner);
        minterFounders.setPriceFounders020(newPrice);

        assertEq(minterFounders.priceFounders020(), newPrice, "Price should be updated");
    }

    function test_setPriceFounders025() public {
        uint256 newPrice = 0.35 ether;

        vm.prank(owner);
        minterFounders.setPriceFounders025(newPrice);

        assertEq(minterFounders.priceFounders025(), newPrice, "Price should be updated");
    }

    function test_setPrice_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setPriceFounders020(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setTreasury() public {
        Treasury newTreasury = new Treasury(address(authority));

        vm.prank(owner);
        minterFounders.setTreasury(address(newTreasury));

        // Note: MinterFounders doesn't have a getter for treasury, 
        // but we can verify by attempting a mint and checking balance
    }

    function test_setTreasury_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setTreasury(address(0x123));
    }

    /*//////////////////////////////////////////////////////////////
                    KONDUX FOUNDERS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setKonduxFounders() public {
        MockKonduxFounders newFounders = new MockKonduxFounders("New Founders", "NF");

        vm.prank(owner);
        minterFounders.setKonduxFounders(address(newFounders));

        // Verify by checking that new mints go to new contract
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFreeFounders(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        minterFounders.whitelistMintFreeFounders(proof);

        assertEq(newFounders.balanceOf(user), 1, "User should have NFT in new contract");
        assertEq(konduxFounders.balanceOf(user), 0, "User should not have NFT in old contract");
    }

    function test_setKonduxFounders_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setKonduxFounders(address(0x123));
    }

    /*//////////////////////////////////////////////////////////////
                        ROOT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_setRootFounders020_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setRootFounders020(keccak256("test"));
    }

    function test_setRootFounders025_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setRootFounders025(keccak256("test"));
    }

    function test_setRootFreeFounders_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setRootFreeFounders(keccak256("test"));
    }

    function test_setRootFreeKNFT_revertsIfNotGovernor() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        minterFounders.setRootFreeKNFT(keccak256("test"));
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function test_treasuryWithdraw() public {
        // First do a paid mint to get ETH in treasury
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        assertEq(address(treasury).balance, PRICE_020, "Treasury should have ETH");

        // Owner withdraws
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        treasury.withdrawEther(PRICE_020);

        assertEq(owner.balance - ownerBalanceBefore, PRICE_020, "Owner should receive ETH");
        assertEq(address(treasury).balance, 0, "Treasury should be empty");
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    function test_claimsAreIndependent() public {
        // User can claim from all tiers independently
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32 root = leaf;

        vm.startPrank(owner);
        minterFounders.setRootFounders020(root);
        minterFounders.setRootFounders025(root);
        minterFounders.setRootFreeFounders(root);
        minterFounders.setRootFreeKNFT(root);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);

        // User claims from all tiers
        vm.startPrank(user);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);
        minterFounders.whitelistMintFounders025{value: PRICE_025}(proof);
        minterFounders.whitelistMintFreeFounders(proof);
        minterFounders.whitelistMintFreeKNFT(proof);
        vm.stopPrank();

        // User should have 3 founders NFTs and 1 kNFT
        assertEq(konduxFounders.balanceOf(user), 3, "User should have 3 founders NFTs");
        assertEq(kondux.balanceOf(user), 1, "User should have 1 kNFT");

        // All claims should be marked
        assertTrue(minterFounders.founders020Claimed(user), "020 should be claimed");
        assertTrue(minterFounders.founders025Claimed(user), "025 should be claimed");
        assertTrue(minterFounders.freeFoundersClaimed(user), "Free founders should be claimed");
        assertTrue(minterFounders.freeKNFTClaimed(user), "Free KNFT should be claimed");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_whitelistMint_variableAddresses(address minter) public {
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0); // EOA only
        vm.deal(minter, 1 ether);

        bytes32 leaf = keccak256(abi.encodePacked(minter));
        bytes32 root = leaf;

        vm.prank(owner);
        minterFounders.setRootFounders020(root);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(minter);
        minterFounders.whitelistMintFounders020{value: PRICE_020}(proof);

        assertEq(konduxFounders.balanceOf(minter), 1, "Minter should have 1 NFT");
    }
}
