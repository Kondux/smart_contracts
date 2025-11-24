// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {StakingV2} from "contracts/StakingV2.sol";
import {Authority} from "contracts/Authority.sol";
import {Treasury} from "contracts/Treasury.sol";
import {IKonduxERC20} from "contracts/interfaces/IKonduxERC20.sol";
import {Helix} from "contracts/Helix.sol";
import {KonduxERC721Founders} from "contracts/tests/KonduxERC721Founders.sol";
import {KonduxERC721kNFT} from "contracts/tests/KonduxERC721kNFT.sol";

contract StakingV2MainnetTest is Test {
    using stdJson for string;

    string internal constant SNAPSHOT_PATH = "forge-tests/utils/fixtures/stakingV2-mainnet.json";

    Authority internal authority;
    Treasury internal treasury;
    IKonduxERC20 internal kondux;
    Helix internal helix;
    KonduxERC721Founders internal founders;
    KonduxERC721kNFT internal knft;
    StakingV2 internal staking;

    address internal governor;
    address internal user;
    address internal other;

    uint256 internal stakeAmount;

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");

    struct SnapshotConfig {
        address authority;
        address treasury;
        address kondux;
        address helix;
        address founders;
        address knft;
        address stakingGovernor;
        uint256 blockNumber;
    }

    SnapshotConfig internal snapshot;

    function setUp() public {
        snapshot = _loadSnapshot();

        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), snapshot.blockNumber);
        vm.selectFork(forkId);

        authority = Authority(snapshot.authority);
        treasury = Treasury(payable(snapshot.treasury));
        kondux = IKonduxERC20(snapshot.kondux);
        helix = new Helix("Helix", "HLX");
        founders = new KonduxERC721Founders();
        knft = new KonduxERC721kNFT();

        governor = snapshot.stakingGovernor;
        user = makeAddr("user");
        other = makeAddr("other");

        stakeAmount = 1_000 * 10 ** kondux.decimals();

        vm.startPrank(governor);
        staking = new StakingV2(
            address(authority), address(kondux), address(treasury), address(founders), address(knft), address(helix)
        );

        treasury.setPermission(Treasury.STATUS.RESERVETOKEN, address(kondux), true);
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(staking), true);
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, address(staking), true);
        treasury.setStakingContract(address(staking));
        treasury.erc20ApprovalSetup(address(kondux), type(uint256).max);

        staking.setAuthorizedERC20(address(kondux), true);
        staking.setMinStake(10_000_000, address(kondux));
        staking.setAPR(25, address(kondux));
        vm.stopPrank();

        helix.setAllowedContract(address(staking), true);
        helix.setRole(MINTER_ROLE, address(staking), true);
        helix.setRole(BURNER_ROLE, address(staking), true);

        uint256 treasuryBalance = kondux.balanceOf(snapshot.treasury);
        require(treasuryBalance >= stakeAmount * 20, "insufficient treasury balance for test");

        vm.prank(snapshot.treasury);
        kondux.transfer(user, stakeAmount * 10);

        vm.prank(snapshot.treasury);
        kondux.transfer(other, stakeAmount * 10);

        vm.prank(user);
        kondux.approve(address(staking), type(uint256).max);

        vm.prank(other);
        kondux.approve(address(staking), type(uint256).max);
    }

    function testAprSnapshotsPerDeposit() public {
        uint256 initialApr = staking.getAPR(address(kondux));

        vm.prank(user);
        uint256 depositId1 = staking.deposit(stakeAmount, 0, address(kondux));

        (uint256 snapshot1, bool exists1) = staking.getDepositAprSnapshot(depositId1);
        assertTrue(exists1, "snapshot missing for first deposit");
        assertEq(snapshot1, initialApr, "snapshot does not match initial APR");

        vm.prank(governor);
        staking.setAPR(50, address(kondux));
        uint256 updatedApr = staking.getAPR(address(kondux));
        assertEq(updatedApr, 50, "APR update failed");

        vm.prank(other);
        uint256 depositId2 = staking.deposit(stakeAmount, 0, address(kondux));

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
        uint256 depositId = staking.deposit(stakeAmount, 0, address(kondux));

        uint256 startTimestamp = block.timestamp;

        vm.warp(startTimestamp + 1 days);
        vm.prank(user);
        staking.stakeRewards(depositId);

        vm.prank(governor);
        staking.setAPR(75, address(kondux));
        uint256 currentApr = staking.getAPR(address(kondux));
        (uint256 originalApr, bool exists) = staking.getDepositAprSnapshot(depositId);
        assertTrue(exists, "snapshot missing");

        vm.warp(startTimestamp + 2 days);
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(StakingV2.APRChangedForDeposit.selector, depositId, originalApr, currentApr)
        );
        staking.stakeRewards(depositId);
        vm.stopPrank();
    }

    function testRestakeAllowedWhenAprUnchanged() public {
        vm.prank(user);
        uint256 depositId = staking.deposit(stakeAmount, 0, address(kondux));

        uint256 startTimestamp = block.timestamp;

        vm.warp(startTimestamp + 1 days);
        vm.prank(user);
        staking.stakeRewards(depositId);

        vm.warp(startTimestamp + 2 days);
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

    function _loadSnapshot() internal view returns (SnapshotConfig memory cfg) {
        string memory json = vm.readFile(SNAPSHOT_PATH);
        cfg.authority = json.readAddress(".authority");
        cfg.treasury = json.readAddress(".treasury");
        cfg.kondux = json.readAddress(".kondux");
        cfg.helix = json.readAddress(".helix");
        cfg.founders = json.readAddress(".founders");
        cfg.knft = json.readAddress(".knft");
        cfg.stakingGovernor = json.readAddress(".stakingGovernor");
        cfg.blockNumber = json.readUint(".blockNumber");
    }
}
