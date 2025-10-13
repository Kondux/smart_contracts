// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./utils/ForgeTestBase.sol";
import {Staking} from "contracts/Staking.sol";
import {Authority} from "contracts/Authority.sol";
import {Treasury} from "contracts/Treasury.sol";
import {KNDX} from "contracts/KNDX_ERC20.sol";
import {Helix} from "contracts/Helix.sol";
import {KonduxERC721Founders} from "contracts/tests/KonduxERC721Founders.sol";
import {MockKondux} from "./utils/MockKondux.sol";

contract StakingTest is ForgeTestBase {
    Staking internal staking;
    Authority internal authority;
    Treasury internal treasury;
    KNDX internal kondux;
    KNDX internal kondux2;
    Helix internal helix;
    KonduxERC721Founders internal founders;
    MockKondux internal knft;

    address internal owner;
    address internal staker;
    address internal staker2;

    uint256 internal constant LARGE_APPROVAL = 1e38;
    uint256 internal constant TREASURY_DEPOSIT = 1e28;
    uint256 internal constant STAKE_AMOUNT = 1e18;
    uint256 internal constant WITHDRAW_AMOUNT = 1e7;
    uint256 internal constant HOURLY_TOLERANCE = 1e13;
    uint256 internal constant REWARD_TOLERANCE = 1e16;

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function setUp() public {
        owner = vm.addr(1);
        staker = vm.addr(2);
        staker2 = vm.addr(3);

    vm.startPrank(owner, owner);
        authority = new Authority(owner, owner, owner, owner);
        treasury = new Treasury(address(authority));
        authority.pushVault(address(treasury), true);

        kondux = new KNDX();
        kondux.enableTrading();
        kondux.faucet();

        kondux2 = new KNDX();
        kondux2.enableTrading();
        kondux2.faucet();

        helix = new Helix("Helix", "HLX");
        founders = new KonduxERC721Founders();
        knft = new MockKondux(
            "Kondux NFT",
            "KNFT",
            address(0),
            address(0),
            address(kondux),
            address(founders),
            owner,
            0
        );

        staking = new Staking(
            address(authority),
            address(kondux),
            address(treasury),
            address(founders),
            address(knft),
            address(helix)
        );

        treasury.setPermission(Treasury.STATUS.RESERVETOKEN, address(kondux), true);
        treasury.setPermission(Treasury.STATUS.RESERVETOKEN, address(kondux2), true);
        treasury.setStakingContract(address(staking));
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(staking), true);
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, address(staking), true);
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, owner, true);
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, owner, true);

        treasury.erc20ApprovalSetup(address(kondux), LARGE_APPROVAL);
        treasury.erc20ApprovalSetup(address(kondux2), LARGE_APPROVAL);

    kondux.approve(address(treasury), LARGE_APPROVAL);

    vm.stopPrank();

    vm.prank(owner, owner);
    treasury.deposit(TREASURY_DEPOSIT, address(kondux));

    vm.startPrank(owner);

    helix.setAllowedContract(address(staking), true);
    helix.setRole(MINTER_ROLE, address(staking), true);
    helix.setRole(BURNER_ROLE, address(staking), true);

    uint256 mintedTokenId = knft.safeMint(owner, 0);
    knft.writeGen(mintedTokenId, 1, 0, 1);
    knft.writeGen(mintedTokenId, 5, 1, 2);

    vm.stopPrank();
    }

    function warp(uint256 secondsForward) internal {
        vm.warp(block.timestamp + secondsForward);
    }

    function expectedMonthlyReward() internal pure returns (uint256) {
        return STAKE_AMOUNT / 4 / 12;
    }

    function expectedDailyReward() internal pure returns (uint256) {
        return STAKE_AMOUNT / 4 / 12 / 30;
    }

    function expectedHourlyReward() internal pure returns (uint256) {
        return STAKE_AMOUNT / 4 / 12 / 30 / 24;
    }

    function netAmountAfterFee(uint256 amount) internal pure returns (uint256) {
        return amount * 9900 / 10000;
    }

    function expectedRewardForElapsed(
        uint256 principal,
        uint256 apr,
        uint256 boost,
        uint256 divisor,
        uint256 elapsedSeconds
    ) internal pure returns (uint256) {
        uint256 rewardPerSecond = (principal * apr * 1e18) / (365 days * 100);
        uint256 baseReward = (elapsedSeconds * rewardPerSecond) / 1e18;
        return (baseReward * boost) / divisor;
    }

    function setTimelock(uint256 depositId, uint256 timestamp) internal {
        bytes32 slot = keccak256(abi.encode(depositId, uint256(3)));
        bytes32 timelockSlot = bytes32(uint256(slot) + 7);
        vm.store(address(staking), timelockSlot, bytes32(timestamp));
    }

    function mintFaucet(address account, KNDX token) internal {
        vm.prank(account);
        token.faucet();
    }

    function approveForStaking(address account, KNDX token) internal {
        vm.prank(account);
        token.approve(address(staking), LARGE_APPROVAL);
    }

    function testMintBoostRewardsRemainStable() public {
        uint256 timeIncrease = 4 weeks + 1 hours;

        assertEq(knft.balanceOf(staker), 0, "initial knft balance");

        vm.startPrank(owner);
        uint256 mintedTokenId = knft.safeMint(staker, 0);
        knft.writeGen(mintedTokenId, 1, 0, 1);
        uint256 bonus = 5;
        knft.writeGen(mintedTokenId, bonus, 1, 2);
        vm.stopPrank();

        assertEq(knft.balanceOf(staker), 1, "knft balance after mint");
    assertEq(uint256(knft.readGen(mintedTokenId, 1, 2)), bonus, "dna boost mismatch");

        mintFaucet(staker, kondux);
        approveForStaking(staker, kondux);

        uint256 beforeRewards = staking.getTotalRewards(address(kondux));
        assertEq(beforeRewards, 0, "initial total rewards");

        vm.startPrank(staker);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 3, address(kondux));
        vm.stopPrank();

        assertEq(staking.getTotalStaked(address(kondux)), STAKE_AMOUNT, "total staked");
        assertEq(staking.getUserTotalStakedByCoin(staker, address(kondux)), STAKE_AMOUNT, "user staked");

        uint256 helixRatio = staking.getRatioERC20(address(kondux));
        uint256 expectedHelix = STAKE_AMOUNT * helixRatio * 1e9;
        assertEq(helix.balanceOf(staker), expectedHelix, "helix balance");

        (uint256 stakeAmount, uint256 unclaimed) = staking.getDepositInfo(depositId);
        assertEq(stakeAmount, STAKE_AMOUNT, "deposit stake");
        assertEq(unclaimed, 0, "unclaimed");

        assertApproxEqAbs(staking.compoundRewardsTimer(depositId), 1 days, 10, "compound timer");
        assertEq(staking.calculateRewards(staker, depositId), 0, "initial rewards");

        warp(timeIncrease);

        assertEq(staking.compoundRewardsTimer(depositId), 0, "timer after warp");
        uint256 reward = staking.calculateRewards(staker, depositId);
        assertApproxEqAbs(reward, expectedMonthlyReward(), REWARD_TOLERANCE, "monthly reward");

        uint256[] memory bonuses = new uint256[](4);
        bonuses[0] = 1;
        bonuses[1] = 10;
        bonuses[2] = 25;
        bonuses[3] = 50;

        for (uint256 i = 0; i < bonuses.length; i++) {
            vm.startPrank(owner);
            uint256 tokenId = knft.safeMint(staker, 0);
            knft.writeGen(tokenId, 1, 0, 1);
            knft.writeGen(tokenId, bonuses[i], 1, 2);
            vm.stopPrank();
            assertEq(uint256(knft.readGen(tokenId, 1, 2)), bonuses[i], "bonus dna mismatch");
        }

        assertEq(knft.balanceOf(staker), 5, "total knft owned");

        uint256 rewardAfterBoost = staking.calculateRewards(staker, depositId);
        assertApproxEqAbs(rewardAfterBoost, expectedMonthlyReward(), REWARD_TOLERANCE, "reward after boosts");
    }

    function testStakeHourlyRewardAndClaim() public {
        uint256 timeIncrease = 1 hours;

        mintFaucet(staker, kondux);
        approveForStaking(staker, kondux);

        vm.startPrank(staker);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));
        vm.stopPrank();

        setTimelock(depositId, block.timestamp);

        assertApproxEqAbs(staking.compoundRewardsTimer(depositId), 1 days, 10, "timer start");
        assertEq(staking.calculateRewards(staker, depositId), 0, "initial calc");

        warp(timeIncrease);

        uint256 rewardHour = staking.calculateRewards(staker, depositId);
        assertApproxEqAbs(rewardHour, expectedDailyReward(), REWARD_TOLERANCE, "reward after 1h");

        warp(timeIncrease);

        uint256 rewardTwoHours = staking.calculateRewards(staker, depositId);
        uint256 expectedTwoHours = expectedDailyReward() * 2;
        assertApproxEqAbs(rewardTwoHours, expectedTwoHours, REWARD_TOLERANCE * 2, "reward after 2h");

        uint256 balanceBefore = kondux.balanceOf(staker);
        vm.startPrank(staker);
        staking.claimRewards(depositId);
        vm.stopPrank();

        uint256 netReward = kondux.balanceOf(staker) - balanceBefore;
        assertApproxEqAbs(netReward, expectedHourlyReward() * 2, HOURLY_TOLERANCE * 2, "net reward");

        uint256 userTotalRewards = staking.getUserTotalRewardsByCoin(staker, address(kondux));
        uint256 totalRewards = staking.getTotalRewards(address(kondux));
        uint256 expectedNet = netAmountAfterFee(expectedHourlyReward() * 2);
        assertApproxEqAbs(userTotalRewards, expectedNet, HOURLY_TOLERANCE * 2, "user total reward");
        assertApproxEqAbs(totalRewards, expectedNet, HOURLY_TOLERANCE * 2, "total reward");

        assertApproxEqAbs(staking.calculateRewards(staker, depositId), 0, HOURLY_TOLERANCE, "rewards after claim");

        uint256 expectedBalance = 1e29 - STAKE_AMOUNT;
        assertApproxEqAbs(kondux.balanceOf(staker), expectedBalance, 1e17, "staker balance");
    }

    function testStakeAdvanceDayWithdrawPartial() public {
        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 3, address(kondux));
        vm.stopPrank();

        setTimelock(depositId, block.timestamp);

        uint256 helixRatio = staking.getRatioERC20(address(kondux));
        uint256 expectedHelix = STAKE_AMOUNT * helixRatio * 1e9;
        assertEq(helix.balanceOf(owner), expectedHelix, "helix initial");

        warp(1 hours);

        uint256 rewardHourly = staking.calculateRewards(owner, depositId);
        assertApproxEqAbs(rewardHourly, expectedDailyReward(), REWARD_TOLERANCE, "hour reward");

        warp(1 hours);

        uint256 balanceBefore = kondux.balanceOf(owner);
        vm.startPrank(owner);
        staking.withdraw(WITHDRAW_AMOUNT, depositId);
        vm.stopPrank();

        uint256 expectedLiquid = netAmountAfterFee(WITHDRAW_AMOUNT);
        uint256 balanceAfter = kondux.balanceOf(owner);
        assertApproxEqAbs(balanceAfter - balanceBefore, expectedLiquid, WITHDRAW_AMOUNT, "withdrawn amount");

        uint256 expectedHelixAfter = expectedHelix - WITHDRAW_AMOUNT * helixRatio * 1e9;
        assertEq(helix.balanceOf(owner), expectedHelixAfter, "helix after withdraw");

        (uint256 stakeAmountAfter, ) = staking.getDepositInfo(depositId);
        assertEq(stakeAmountAfter, STAKE_AMOUNT - WITHDRAW_AMOUNT, "stake after withdraw");

        assertEq(staking.getDepositIds(owner).length, 1, "deposit count");
        assertEq(staking.getDepositIds(owner)[0], depositId, "deposit id");
    }

    function testStakeYearAddSecondToken() public {
        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 3, address(kondux));
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(owner);
        staking.withdraw(10_000, depositId);

        warp(365 days);

        assertEq(staking.compoundRewardsTimer(depositId), 0, "timer after year");
        (uint256 stakeAmount, ) = staking.getDepositInfo(depositId);
        uint256 apr = staking.aprERC20(address(kondux));
        uint256 boost = staking.calculateBoostPercentage(owner, depositId);
        uint256 divisor = staking.divisorERC20(address(kondux));
        uint256 expectedYearly = expectedRewardForElapsed(stakeAmount, apr, boost, divisor, 365 days);
        assertApproxEqAbs(staking.calculateRewards(owner, depositId), expectedYearly, REWARD_TOLERANCE * 10, "reward year");

        warp(365 days);

        vm.startPrank(owner);
        staking.withdraw(10_000, depositId);
        vm.stopPrank();

        approveForStaking(owner, kondux2);

        vm.startPrank(owner);
        staking.addNewStakingToken(address(kondux2), 25, 1 days, 100, 1_000, 500, 10_000, 10_000);
        vm.stopPrank();

        vm.prank(owner);
        treasury.erc20ApprovalSetup(address(kondux2), LARGE_APPROVAL);

        vm.startPrank(owner);
        uint256 depositId2 = staking.deposit(STAKE_AMOUNT, 3, address(kondux2));
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(owner);
        staking.withdraw(10_000, depositId2);

        warp(365 days);

    (uint256 stakeAmount2, ) = staking.getDepositInfo(depositId2);
    uint256 apr2 = staking.aprERC20(address(kondux2));
    uint256 boost2 = staking.calculateBoostPercentage(owner, depositId2);
    uint256 divisor2 = staking.divisorERC20(address(kondux2));
    uint256 expectedYearlyToken2 = expectedRewardForElapsed(stakeAmount2, apr2, boost2, divisor2, 365 days);
    assertApproxEqAbs(staking.calculateRewards(owner, depositId2), expectedYearlyToken2, REWARD_TOLERANCE * 10, "reward token2");

        warp(365 days);

        vm.startPrank(owner);
        staking.withdraw(10_000, depositId2);
        vm.stopPrank();

        assertEq(staking.getTotalStaked(address(kondux2)), STAKE_AMOUNT - 10_000, "total staked token2");
    }

    function testStakeYearlyRewardsClaim() public {
        uint256 timeIncrease = 4 weeks;

        mintFaucet(staker, kondux);
        approveForStaking(staker, kondux);

        vm.startPrank(staker);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));
        vm.stopPrank();

        warp(timeIncrease);
        assertApproxEqAbs(staking.compoundRewardsTimer(depositId), 0, 10, "timer after 4w");

        warp(timeIncrease);

        uint256 balanceBefore = kondux.balanceOf(staker);
        vm.startPrank(staker);
        staking.claimRewards(depositId);
        vm.stopPrank();

        uint256 expectedReward = expectedMonthlyReward() * 2;
        uint256 netReward = kondux.balanceOf(staker) - balanceBefore;
        assertApproxEqAbs(netReward, expectedReward, REWARD_TOLERANCE * 2, "net reward 8w");

        assertApproxEqAbs(staking.getUserTotalRewardsByCoin(staker, address(kondux)), netAmountAfterFee(expectedReward), REWARD_TOLERANCE * 2, "user rewards");
    }

    function testStakeYearWithdrawAfterUnlock() public {
        uint256 timeIncrease = 4 weeks;

        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));
        vm.stopPrank();

        warp(timeIncrease);
        assertApproxEqAbs(staking.calculateRewards(owner, depositId), expectedMonthlyReward(), REWARD_TOLERANCE, "monthly reward");

    vm.expectRevert(bytes("Timelock not passed"));
        vm.prank(owner);
        staking.withdraw(10_000, depositId);

        warp(timeIncrease);

        vm.startPrank(owner);
        staking.withdraw(10_000, depositId);
        vm.stopPrank();

        assertEq(staking.getTotalStaked(address(kondux)), STAKE_AMOUNT - 10_000, "total staked after withdraw");
    }

    function testStakeYearAddTokenAfterUnlock() public {
        uint256 timeIncrease = 4 weeks;

        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));
        vm.stopPrank();

        warp(timeIncrease * 2);
        vm.startPrank(owner);
        staking.withdraw(10_000, depositId);
        vm.stopPrank();

        vm.startPrank(owner);
        staking.addNewStakingToken(address(kondux2), 25, 1 days, 100, 1_000, 500, 10_000, 10_000);
        vm.stopPrank();

        vm.prank(owner);
        treasury.erc20ApprovalSetup(address(kondux2), LARGE_APPROVAL);

        approveForStaking(owner, kondux2);

        vm.startPrank(owner);
        uint256 depositId2 = staking.deposit(STAKE_AMOUNT, 0, address(kondux2));
        vm.stopPrank();

        warp(timeIncrease * 2);

        vm.startPrank(owner);
        staking.withdraw(10_000, depositId2);
        vm.stopPrank();

        assertEq(staking.getTotalStaked(address(kondux2)), STAKE_AMOUNT - 10_000, "token2 total staked");
    }

    function testEarlyUnstakePenaltyApplied() public {
        uint256 halfTime = 365 days / 2;
        uint256 toWithdraw = 10_000_000;

        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 3, address(kondux));
        vm.stopPrank();

        warp(halfTime);

    uint256 balanceBefore = kondux.balanceOf(owner);
        uint256 helixBalanceBefore = helix.balanceOf(owner);
        uint256 ratio = staking.getRatioERC20(address(kondux));

        vm.startPrank(owner);
        staking.earlyUnstake(toWithdraw, depositId);
        vm.stopPrank();

        uint256 balanceAfter = kondux.balanceOf(owner);
        uint256 expectedLiquid = toWithdraw;
        uint256 lockDuration = staking.timelockDurations(3);
        uint256 extraFee = (expectedLiquid * staking.earlyWithdrawalPenalty(address(kondux)) * (lockDuration / 2)) / (lockDuration * 100);
        if (extraFee > expectedLiquid) {
            extraFee = expectedLiquid;
        }
        if (extraFee == 0) {
            extraFee = expectedLiquid / 100;
        }
        expectedLiquid = expectedLiquid - extraFee - staking.withdrawalFeeERC20(address(kondux));
        assertApproxEqAbs(
            helix.balanceOf(owner),
            helixBalanceBefore - toWithdraw * ratio * 1e9,
            toWithdraw * ratio * 1e9 / 100,
            "helix after early unstake"
        );

        uint256 expectedStake = STAKE_AMOUNT - toWithdraw;
        (uint256 stakeAmountAfter, ) = staking.getDepositInfo(depositId);
        assertEq(stakeAmountAfter, expectedStake, "stake after early");
        assertApproxEqAbs(balanceAfter - balanceBefore, expectedLiquid, expectedLiquid / 50, "liquid transfer");
        assertApproxEqAbs(balanceAfter % toWithdraw, expectedLiquid, expectedLiquid / 100, "liquid amount");
    }

    function testTreasuryWithdrawFlow() public {
        uint256 ownerBalanceBefore = kondux.balanceOf(owner);
        uint256 treasuryBalanceBefore = kondux.balanceOf(address(treasury));

        assertEq(ownerBalanceBefore, 1e29 - TREASURY_DEPOSIT, "owner balance before");
        assertEq(treasuryBalanceBefore, TREASURY_DEPOSIT, "treasury balance before");

    vm.startPrank(owner, owner);
        treasury.withdraw(TREASURY_DEPOSIT, address(kondux));
        vm.stopPrank();

        assertEq(kondux.balanceOf(owner), 1e29, "owner balance after withdraw");
        assertEq(kondux.balanceOf(address(treasury)), 0, "treasury balance after withdraw");

    vm.startPrank(owner, owner);
        kondux.approve(address(treasury), LARGE_APPROVAL);
        treasury.deposit(TREASURY_DEPOSIT, address(kondux));
        vm.stopPrank();

        assertEq(kondux.balanceOf(owner), 1e29 - TREASURY_DEPOSIT, "owner balance after redeposit");
        assertEq(kondux.balanceOf(address(treasury)), TREASURY_DEPOSIT, "treasury balance after redeposit");
    }

    function testStakeRewardsCompound() public {
        approveForStaking(owner, kondux);

        vm.startPrank(owner);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 3, address(kondux));
        vm.stopPrank();

        uint256 helixRatio = staking.getRatioERC20(address(kondux));
        uint256 helixBefore = helix.balanceOf(owner);

        warp(1 hours * 2);

        uint256 expectedRewards = staking.calculateRewards(owner, depositId);

        vm.startPrank(owner);
        staking.stakeRewards(depositId);
        vm.stopPrank();

        (uint256 stakeAfter, uint256 unclaimedAfter) = staking.getDepositInfo(depositId);
        assertTrue(unclaimedAfter == 0, "unclaimed after stake");
        assertTrue(stakeAfter > STAKE_AMOUNT, "stake increased");

        uint256 compounded = stakeAfter - STAKE_AMOUNT;
        assertApproxEqAbs(compounded, expectedRewards, HOURLY_TOLERANCE * 2, "compounded amount");

        uint256 expectedHelix = helixBefore + (stakeAfter - STAKE_AMOUNT) * helixRatio * 1e9;
        assertEq(helix.balanceOf(owner), expectedHelix, "helix after stake");
    }

    function testMultipleRewardClaims() public {
        uint256 timeIncrease = 1 hours;
        uint256 numberOfClaims = 3;

        mintFaucet(staker, kondux);
        approveForStaking(staker, kondux);

        vm.startPrank(staker);
        uint256 depositId = staking.deposit(STAKE_AMOUNT, 0, address(kondux));
        vm.stopPrank();

        setTimelock(depositId, block.timestamp);

        uint256 totalNet;
        bytes32 rewardTopic = keccak256("Reward(address,uint256,uint256)");
        bytes32 stakerTopic = bytes32(uint256(uint160(staker)));

        for (uint256 i = 1; i <= numberOfClaims; i++) {
            warp(timeIncrease);
            uint256 balanceBefore = kondux.balanceOf(staker);
            vm.recordLogs();
            vm.startPrank(staker);
            staking.claimRewards(depositId);
            vm.stopPrank();
            Vm.Log[] memory entries = vm.getRecordedLogs();
            uint256 gained = kondux.balanceOf(staker) - balanceBefore;

            uint256 netReward;
            for (uint256 j = 0; j < entries.length; j++) {
                Vm.Log memory entry = entries[j];
                if (
                    entry.emitter == address(staking) &&
                    entry.topics.length > 1 &&
                    entry.topics[0] == rewardTopic &&
                    entry.topics[1] == stakerTopic
                ) {
                    (netReward, ) = abi.decode(entry.data, (uint256, uint256));
                    break;
                }
            }

            assertGt(netReward, 0, "reward event missing");
            assertApproxEqAbs(gained, netReward, HOURLY_TOLERANCE, "balance gain matches event");

            uint256 expectedNet = netAmountAfterFee(expectedHourlyReward());
            assertApproxEqAbs(netReward, expectedNet, HOURLY_TOLERANCE, "claim reward");

            totalNet += netReward;

            assertApproxEqAbs(
                staking.getUserTotalRewardsByCoin(staker, address(kondux)),
                totalNet,
                HOURLY_TOLERANCE * i,
                "user total after claim"
            );
            assertApproxEqAbs(
                staking.getTotalRewards(address(kondux)),
                totalNet,
                HOURLY_TOLERANCE * i,
                "total rewards after claim"
            );
        }

        uint256 expectedBalance = 1e29 - STAKE_AMOUNT + totalNet;
        assertApproxEqAbs(
            kondux.balanceOf(staker),
            expectedBalance,
            HOURLY_TOLERANCE * numberOfClaims,
            "final staker balance"
        );
    }
}
