// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../contracts/Authority.sol";

/**
 * @title Authority Tests
 * @notice Forge tests for the Authority contract - role management with push/pull mechanics
 * @dev Migrated from test/authority.test.js
 */
contract AuthorityTest is Test {
    Authority public authority;

    address public owner;
    address public newGuy;

    function setUp() public {
        owner = makeAddr("owner");
        newGuy = makeAddr("newGuy");

        vm.startPrank(owner);
        authority = new Authority(owner, owner, owner, owner);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(authority.governor(), owner, "Governor should be owner");
        assertEq(authority.guardian(), owner, "Guardian should be owner");
        assertEq(authority.vault(), owner, "Vault should be owner");
        assertEq(authority.policy(), owner, "Policy should be owner");
    }

    function test_constructor_revertsOnZeroAddresses() public {
        vm.expectRevert("Governor cannot be zero address");
        new Authority(address(0), owner, owner, owner);

        vm.expectRevert("Guardian cannot be zero address");
        new Authority(owner, address(0), owner, owner);

        vm.expectRevert("Policy cannot be zero address");
        new Authority(owner, owner, address(0), owner);

        vm.expectRevert("Vault cannot be zero address");
        new Authority(owner, owner, owner, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNOR PUSH/PULL
    //////////////////////////////////////////////////////////////*/

    function test_pushGovernor_effectiveImmediately() public {
        vm.prank(owner);
        authority.pushGovernor(newGuy, true);

        assertEq(authority.governor(), newGuy, "Governor should be updated immediately");
        assertEq(authority.newGovernor(), newGuy, "newGovernor should be set");
    }

    function test_pushGovernor_effectiveAfterPull() public {
        vm.prank(owner);
        authority.pushGovernor(newGuy, false);

        // Governor should still be owner until pull
        assertEq(authority.governor(), owner, "Governor should not change yet");
        assertEq(authority.newGovernor(), newGuy, "newGovernor should be set");

        // newGuy pulls the role
        vm.prank(newGuy);
        authority.pullGovernor();

        assertEq(authority.governor(), newGuy, "Governor should be updated after pull");
    }

    function test_pullGovernor_revertsIfNotNewGovernor() public {
        vm.prank(owner);
        authority.pushGovernor(newGuy, false);

        // Random address tries to pull
        address randomGuy = makeAddr("random");
        vm.prank(randomGuy);
        vm.expectRevert("!newGovernor");
        authority.pullGovernor();
    }

    function test_pushGovernor_revertsIfNotGovernor() public {
        vm.prank(newGuy);
        vm.expectRevert(); // onlyGovernor modifier
        authority.pushGovernor(newGuy, true);
    }

    function test_pushGovernor_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Account cannot be zero address");
        authority.pushGovernor(address(0), true);
    }

    /*//////////////////////////////////////////////////////////////
                        GUARDIAN PUSH/PULL
    //////////////////////////////////////////////////////////////*/

    function test_pushGuardian_effectiveImmediately() public {
        vm.prank(owner);
        authority.pushGuardian(newGuy, true);

        assertEq(authority.guardian(), newGuy, "Guardian should be updated immediately");
    }

    function test_pushGuardian_effectiveAfterPull() public {
        vm.prank(owner);
        authority.pushGuardian(newGuy, false);

        assertEq(authority.guardian(), owner, "Guardian should not change yet");
        assertEq(authority.newGuardian(), newGuy, "newGuardian should be set");

        vm.prank(newGuy);
        authority.pullGuardian();

        assertEq(authority.guardian(), newGuy, "Guardian should be updated after pull");
    }

    function test_pullGuardian_revertsIfNotNewGuardian() public {
        vm.prank(owner);
        authority.pushGuardian(newGuy, false);

        address randomGuy = makeAddr("random");
        vm.prank(randomGuy);
        vm.expectRevert("!newGuard");
        authority.pullGuardian();
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT PUSH/PULL
    //////////////////////////////////////////////////////////////*/

    function test_pushVault_effectiveImmediately() public {
        vm.prank(owner);
        authority.pushVault(newGuy, true);

        assertEq(authority.vault(), newGuy, "Vault should be updated immediately");
    }

    function test_pushVault_effectiveAfterPull() public {
        vm.prank(owner);
        authority.pushVault(newGuy, false);

        assertEq(authority.vault(), owner, "Vault should not change yet");
        assertEq(authority.newVault(), newGuy, "newVault should be set");

        vm.prank(newGuy);
        authority.pullVault();

        assertEq(authority.vault(), newGuy, "Vault should be updated after pull");
    }

    function test_pullVault_revertsIfNotNewVault() public {
        vm.prank(owner);
        authority.pushVault(newGuy, false);

        address randomGuy = makeAddr("random");
        vm.prank(randomGuy);
        vm.expectRevert("!newVault");
        authority.pullVault();
    }

    /*//////////////////////////////////////////////////////////////
                         POLICY PUSH/PULL
    //////////////////////////////////////////////////////////////*/

    function test_pushPolicy_effectiveImmediately() public {
        vm.prank(owner);
        authority.pushPolicy(newGuy, true);

        assertEq(authority.policy(), newGuy, "Policy should be updated immediately");
    }

    function test_pushPolicy_effectiveAfterPull() public {
        vm.prank(owner);
        authority.pushPolicy(newGuy, false);

        assertEq(authority.policy(), owner, "Policy should not change yet");
        assertEq(authority.newPolicy(), newGuy, "newPolicy should be set");

        vm.prank(newGuy);
        authority.pullPolicy();

        assertEq(authority.policy(), newGuy, "Policy should be updated after pull");
    }

    function test_pullPolicy_revertsIfNotNewPolicy() public {
        vm.prank(owner);
        authority.pushPolicy(newGuy, false);

        address randomGuy = makeAddr("random");
        vm.prank(randomGuy);
        vm.expectRevert("!newPolicy");
        authority.pullPolicy();
    }

    /*//////////////////////////////////////////////////////////////
                            ROLES
    //////////////////////////////////////////////////////////////*/

    function test_pushRole() public {
        bytes32 newRole = keccak256("newRole");

        vm.prank(owner);
        authority.pushRole(newGuy, newRole);

        assertEq(authority.roles(newGuy), newRole, "Role should be assigned");
    }

    function test_pushRole_revertsIfNotGovernor() public {
        bytes32 newRole = keccak256("newRole");

        vm.prank(newGuy);
        vm.expectRevert(); // onlyGovernor modifier
        authority.pushRole(newGuy, newRole);
    }

    function test_pushRole_revertsOnZeroAddress() public {
        bytes32 newRole = keccak256("newRole");

        vm.prank(owner);
        vm.expectRevert("Account cannot be zero address");
        authority.pushRole(address(0), newRole);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_isContract() public view {
        // Authority contract itself should be detected as a contract
        assertTrue(authority.isContract(address(authority)), "Should detect contract");

        // EOA should not be detected as contract
        assertFalse(authority.isContract(owner), "Should not detect EOA as contract");
    }
}
