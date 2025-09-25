// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./utils/ForgeTestBase.sol";
import {StakingV2} from "contracts/StakingV2.sol";
import {Authority} from "contracts/Authority.sol";
import {Treasury} from "contracts/Treasury.sol";
import {KNDX} from "contracts/KNDX_ERC20.sol";
import {Helix} from "contracts/Helix.sol";
import {KonduxERC721Founders} from "contracts/tests/KonduxERC721Founders.sol";
import {KonduxERC721kNFT} from "contracts/tests/KonduxERC721kNFT.sol";

contract StakingV2Test is ForgeTestBase {
    StakingV2 internal staking;
    Authority internal authority;
    Treasury internal treasury;
    KNDX internal kondux;
    Helix internal helix;
    KonduxERC721Founders internal founders;
    KonduxERC721kNFT internal knft;

    address internal user;
    address internal other;

    uint256 internal constant STAKE_AMOUNT = 1_000 * 1e18;
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function setUp() public {
        user = vm.addr(1);
        other = vm.addr(2);

        authority = new Authority(address(this), address(this), address(this), address(this));
        treasury = new Treasury(address(authority));
        authority.pushVault(address(treasury), true);

        kondux = new KNDX();
        kondux.enableTrading();
        kondux.faucet();

        helix = new Helix("Helix", "HLX");
        founders = new KonduxERC721Founders();
        knft = new KonduxERC721kNFT();

        staking = new StakingV2(
            address(authority),
            address(kondux),
            address(treasury),
            address(founders),
            address(knft),
            address(helix)
        );

        treasury.setPermission(Treasury.STATUS.RESERVETOKEN, address(kondux), true);
        treasury.setStakingContract(address(staking));
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(staking), true);
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(this), true);
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, address(staking), true);
        treasury.erc20ApprovalSetup(address(kondux), type(uint256).max);

        helix.setAllowedContract(address(staking), true);
        helix.setRole(MINTER_ROLE, address(staking), true);
        helix.setRole(BURNER_ROLE, address(staking), true);

        kondux.transfer(user, STAKE_AMOUNT * 10);
        kondux.transfer(other, STAKE_AMOUNT * 10);

        vm.prank(user);
        kondux.approve(address(staking), type(uint256).max);

        vm.prank(other);
        kondux.approve(address(staking), type(uint256).max);
    }

    function testAprSnapshotsPerDeposit() public {
        uint256 initialApr = staking.getAPR(address(kondux));

        vm.prank(user);
        uint256 depositId1 = staking.deposit(STAKE_AMOUNT, 0, address(kondux));

        (uint256 snapshot1, bool exists1) = staking.getDepositAprSnapshot(depositId1);
        assertTrue(exists1, "snapshot missing for first deposit");
        assertEq(snapshot1, initialApr, "snapshot does not match initial APR");

        staking.setAPR(50, address(kondux));
        uint256 updatedApr = staking.getAPR(address(kondux));
        assertEq(updatedApr, 50, "APR update failed");

        vm.prank(other);
        uint256 depositId2 = staking.deposit(STAKE_AMOUNT, 0, address(kondux));

        (uint256 snapshot2, bool exists2) = staking.getDepositAprSnapshot(depositId2);
        assertTrue(exists2, "snapshot missing for second deposit");
        assertEq(snapshot2, updatedApr, "second snapshot mismatch");

        vm.warp(block.timestamp + 1 days);

        uint256 reward1 = staking.calculateRewards(user, depositId1);
        uint256 reward2 = staking.calculateRewards(other, depositId2);

        assertGt(reward2, reward1, "higher APR deposit should yield more rewards");
    }

    function testRestakeBlockedWhenAprChanges() public {
        vm.prank(user);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        staking.stakeRewards(depositId);

        staking.setAPR(75, address(kondux));
        uint256 currentApr = staking.getAPR(address(kondux));
        (uint256 originalApr, bool exists) = staking.getDepositAprSnapshot(depositId);
        assertTrue(exists, "snapshot missing");

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingV2.APRChangedForDeposit.selector,
                depositId,
                originalApr,
                currentApr
            )
        );
        staking.stakeRewards(depositId);
        vm.stopPrank();
    }

    function testRestakeAllowedWhenAprUnchanged() public {
        vm.prank(user);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        staking.stakeRewards(depositId);

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        staking.stakeRewards(depositId);

        (uint256 snapshotValue, bool exists) = staking.getDepositAprSnapshot(depositId);
        assertTrue(exists, "snapshot missing after compounding");
        assertEq(snapshotValue, staking.getAPR(address(kondux)), "snapshot should match current APR");
    }

    function testSnapshotQueryForUnknownDeposit() public view {
        (uint256 snapshotValue, bool exists) = staking.getDepositAprSnapshot(999);
        assertEq(exists, false, "non-existent deposit should report missing snapshot");
        assertEq(snapshotValue, 0, "non-existent deposit snapshot should be zero");
    }
}
