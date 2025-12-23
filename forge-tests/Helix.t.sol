// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../contracts/Helix.sol";
import "../contracts/tests/MinterContract.sol";
import "../contracts/interfaces/IHelix.sol";

/**
 * @title Helix Token Tests
 * @notice Forge tests for the Helix ERC20 token with access control and whitelisting
 * @dev Migrated from test/helix.test.ts
 */
contract HelixTest is Test {
    Helix public helixToken;
    MinterContract public minterContract;

    address public admin;
    address public minter;
    address public burner;
    address public user1;
    address public user2;
    address public user3;

    bytes32 public constant ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant WHITELIST_MANAGER_ROLE = keccak256("WHITELIST_MANAGER_ROLE");

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.startPrank(admin);
        helixToken = new Helix("Helix", "HLX");
        minterContract = new MinterContract();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(helixToken.name(), "Helix");
        assertEq(helixToken.symbol(), "HLX");
        assertEq(helixToken.totalSupply(), 0);
        assertFalse(helixToken.enableUnrestrictedTransfers());
    }

    function test_adminHasRoles() public view {
        assertTrue(helixToken.hasRole(ADMIN_ROLE, admin));
        assertTrue(helixToken.hasRole(MINTER_ROLE, admin));
        assertTrue(helixToken.hasRole(BURNER_ROLE, admin));
        assertTrue(helixToken.hasRole(WHITELIST_MANAGER_ROLE, admin));
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELISTED CONTRACT TRANSFER
    //////////////////////////////////////////////////////////////*/

    function test_whitelistedContractCanTransfer() public {
        // Add minter contract to whitelist and give it MINTER_ROLE
        vm.startPrank(admin);
        helixToken.setAllowedContract(address(minterContract), true);
        helixToken.setRole(MINTER_ROLE, address(minterContract), true);
        vm.stopPrank();

        // Mint tokens to user1 via the minter contract
        minterContract.mint(IHelix(address(helixToken)), user1, 100);
        assertEq(helixToken.balanceOf(user1), 100);

        // Approve minter contract to transfer user1's tokens
        vm.prank(user1);
        helixToken.approve(address(minterContract), 50);

        // Transfer should succeed via whitelisted contract
        vm.prank(user1);
        minterContract.transferTokens(IHelix(address(helixToken)), user1, user2, 50);

        assertEq(helixToken.balanceOf(user1), 50);
        assertEq(helixToken.balanceOf(user2), 50);
    }

    function test_revokedContractCannotTransfer() public {
        // First, add to whitelist and mint
        vm.startPrank(admin);
        helixToken.setAllowedContract(address(minterContract), true);
        helixToken.setRole(MINTER_ROLE, address(minterContract), true);
        vm.stopPrank();

        minterContract.mint(IHelix(address(helixToken)), user1, 100);

        // Now revoke the contract from whitelist
        vm.prank(admin);
        helixToken.setAllowedContract(address(minterContract), false);

        // Approve and try to transfer - should fail
        vm.prank(user1);
        helixToken.approve(address(minterContract), 50);

        vm.prank(user1);
        vm.expectRevert("HelixToken: direct transfers not allowed");
        minterContract.transferTokens(IHelix(address(helixToken)), user1, user2, 50);
    }

    /*//////////////////////////////////////////////////////////////
                        DIRECT TRANSFER RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function test_directTransferFails() public {
        // Admin mints to user1
        vm.prank(admin);
        helixToken.mint(user1, 100);

        // Direct transfer should fail
        vm.prank(user1);
        vm.expectRevert("HelixToken: direct transfers not allowed");
        helixToken.transfer(user2, 50);
    }

    function test_directTransferSucceedsWhenUnrestricted() public {
        // Admin mints to user1
        vm.prank(admin);
        helixToken.mint(user1, 100);

        // Enable unrestricted transfers
        vm.prank(admin);
        helixToken.setEnableUnrestrictedTransfers(true);

        // Now transfer should succeed
        vm.prank(user1);
        helixToken.transfer(user2, 50);

        assertEq(helixToken.balanceOf(user1), 50);
        assertEq(helixToken.balanceOf(user2), 50);
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING
    //////////////////////////////////////////////////////////////*/

    function test_onlyMinterCanMint() public {
        // Admin has MINTER_ROLE by default
        vm.prank(admin);
        helixToken.mint(user1, 100);
        assertEq(helixToken.balanceOf(user1), 100);
    }

    function test_nonMinterCannotMint() public {
        vm.prank(user1);
        vm.expectRevert("HelixToken: only minter");
        helixToken.mint(user2, 100);
    }

    function test_grantedMinterCanMint() public {
        // Grant MINTER_ROLE to minter
        vm.prank(admin);
        helixToken.setRole(MINTER_ROLE, minter, true);

        // Now minter can mint
        vm.prank(minter);
        helixToken.mint(user1, 100);
        assertEq(helixToken.balanceOf(user1), 100);
    }

    /*//////////////////////////////////////////////////////////////
                            BURNING
    //////////////////////////////////////////////////////////////*/

    function test_onlyBurnerCanBurn() public {
        // Admin mints and burns
        vm.startPrank(admin);
        helixToken.mint(user1, 100);
        helixToken.burn(user1, 50);
        vm.stopPrank();

        assertEq(helixToken.balanceOf(user1), 50);
    }

    function test_nonBurnerCannotBurn() public {
        vm.prank(admin);
        helixToken.mint(user1, 100);

        vm.prank(user1);
        vm.expectRevert("HelixToken: only burner");
        helixToken.burn(user1, 50);
    }

    function test_grantedBurnerCanBurn() public {
        vm.prank(admin);
        helixToken.mint(user1, 100);

        // Grant BURNER_ROLE
        vm.prank(admin);
        helixToken.setRole(BURNER_ROLE, burner, true);

        vm.prank(burner);
        helixToken.burn(user1, 50);
        assertEq(helixToken.balanceOf(user1), 50);
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_setRole_grant() public {
        assertFalse(helixToken.hasRole(MINTER_ROLE, user1));

        vm.prank(admin);
        helixToken.setRole(MINTER_ROLE, user1, true);

        assertTrue(helixToken.hasRole(MINTER_ROLE, user1));
    }

    function test_setRole_revoke() public {
        // Grant first
        vm.prank(admin);
        helixToken.setRole(MINTER_ROLE, user1, true);
        assertTrue(helixToken.hasRole(MINTER_ROLE, user1));

        // Revoke
        vm.prank(admin);
        helixToken.setRole(MINTER_ROLE, user1, false);
        assertFalse(helixToken.hasRole(MINTER_ROLE, user1));
    }

    function test_setRole_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit Helix.RoleChanged(user1, MINTER_ROLE, true);
        helixToken.setRole(MINTER_ROLE, user1, true);
    }

    function test_nonAdminCannotSetRole() public {
        vm.prank(user1);
        vm.expectRevert("HelixToken: only admin");
        helixToken.setRole(MINTER_ROLE, user2, true);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_setAllowedContract() public {
        assertFalse(helixToken.allowedContracts(address(minterContract)));

        vm.prank(admin);
        helixToken.setAllowedContract(address(minterContract), true);

        assertTrue(helixToken.allowedContracts(address(minterContract)));
    }

    function test_setAllowedContract_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit Helix.WhitelistChanged(address(minterContract), true);
        helixToken.setAllowedContract(address(minterContract), true);
    }

    function test_getWhitelistedContracts() public {
        vm.startPrank(admin);
        helixToken.setAllowedContract(address(minterContract), true);
        helixToken.setAllowedContract(user1, true); // even EOAs can be added
        vm.stopPrank();

        address[] memory whitelisted = helixToken.getWhitelistedContracts();
        assertEq(whitelisted.length, 2);
        assertEq(whitelisted[0], address(minterContract));
        assertEq(whitelisted[1], user1);
    }

    function test_nonWhitelistManagerCannotSetAllowed() public {
        vm.prank(user1);
        vm.expectRevert("HelixToken: only whitelist manager");
        helixToken.setAllowedContract(address(minterContract), true);
    }

    /*//////////////////////////////////////////////////////////////
                          PAUSE/UNPAUSE
    //////////////////////////////////////////////////////////////*/

    function test_adminCanPause() public {
        vm.prank(admin);
        helixToken.pause();
        assertTrue(helixToken.paused());
    }

    function test_adminCanUnpause() public {
        vm.prank(admin);
        helixToken.pause();

        vm.prank(admin);
        helixToken.unpause();
        assertFalse(helixToken.paused());
    }

    function test_nonAdminCannotPause() public {
        vm.prank(user1);
        vm.expectRevert("HelixToken: only admin");
        helixToken.pause();
    }

    /*//////////////////////////////////////////////////////////////
                    UNRESTRICTED TRANSFERS TOGGLE
    //////////////////////////////////////////////////////////////*/

    function test_setEnableUnrestrictedTransfers() public {
        assertFalse(helixToken.enableUnrestrictedTransfers());

        vm.prank(admin);
        helixToken.setEnableUnrestrictedTransfers(true);

        assertTrue(helixToken.enableUnrestrictedTransfers());
    }

    function test_nonAdminCannotToggleUnrestrictedTransfers() public {
        vm.prank(user1);
        vm.expectRevert("HelixToken: only admin");
        helixToken.setEnableUnrestrictedTransfers(true);
    }

    /*//////////////////////////////////////////////////////////////
                        MINT/BURN TO/FROM ZERO
    //////////////////////////////////////////////////////////////*/

    function test_mintingFromZeroAllowed() public {
        // Minting is from address(0), should always work
        vm.prank(admin);
        helixToken.mint(user1, 100);
        assertEq(helixToken.balanceOf(user1), 100);
    }

    function test_burningToZeroAllowed() public {
        vm.prank(admin);
        helixToken.mint(user1, 100);

        vm.prank(admin);
        helixToken.burn(user1, 100);
        assertEq(helixToken.balanceOf(user1), 0);
    }
}
