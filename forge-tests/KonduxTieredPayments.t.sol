// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxTieredPayments.sol";
import "../contracts/Treasury.sol";
import "../contracts/Authority.sol";
import "../contracts/tests/KonduxERC20.sol";
import "../contracts/tests/MockKondux.sol";
import "../contracts/tests/MockOracle.sol";

/**
 * @title KonduxTieredPayments Tests
 * @notice Forge tests for KonduxTieredPayments - tiered billing, oracle, NFT discounts
 * @dev Migrated from test/konduxTieredPayments.test.js
 */
contract KonduxTieredPaymentsTest is Test {
    KonduxTieredPayments public payments;
    Treasury public treasury;
    Authority public authority;
    KonduxERC20 public token;
    MockKondux public mockNFT;
    UsageOracleMock public usageOracle;

    address public owner;
    address public governor;
    address public provider;
    address public user;
    address public other;

    uint256 constant ONE_TOKEN = 1 ether;
    uint256 constant LOCK_PERIOD = 3600; // 1 hour

    bytes32 constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    function setUp() public {
        owner = makeAddr("owner");
        governor = makeAddr("governor");
        provider = makeAddr("provider");
        user = makeAddr("user");
        other = makeAddr("other");

        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(provider, 100 ether);

        vm.startPrank(owner);

        // Deploy Authority (owner is governor, guardian, policy, and vault)
        authority = new Authority(owner, owner, owner, owner);

        // Deploy ERC20 token (stablecoin mock)
        token = new KonduxERC20();

        // Deploy usage oracle mock
        usageOracle = new UsageOracleMock();

        // Deploy NFT mock
        mockNFT = new MockKondux();

        // Deploy Treasury
        treasury = new Treasury(address(authority));

        // Deploy KonduxTieredPayments
        payments = new KonduxTieredPayments(
            address(treasury),
            governor,
            address(token),
            LOCK_PERIOD,
            governor // using governor as royalty receiver
        );

        vm.stopPrank();

        // Setup: governor configures payments contract
        vm.startPrank(governor);
        payments.setUsageOracle(address(usageOracle));
        
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(mockNFT);
        payments.setNFTContracts(nftContracts);
        vm.stopPrank();

        // Provider registers with fallback rate = 3
        vm.prank(provider);
        payments.registerProvider(0, 3);

        // Provider sets tiers: tier1: up to 100 units at cost=1, tier2: up to 200 at cost=2
        vm.prank(provider);
        uint256[] memory thresholds = new uint256[](2);
        thresholds[0] = 100;
        thresholds[1] = 200;
        uint256[] memory costs = new uint256[](2);
        costs[0] = 1;
        costs[1] = 2;
        payments.setProviderTiers(thresholds, costs);

        // Setup treasury permissions
        vm.startPrank(owner);
        // Allow payments contract as reserve depositor (STATUS = 0)
        treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, address(payments), true);
        // Allow payments contract as reserve spender (STATUS = 1)
        treasury.setPermission(Treasury.STATUS.RESERVESPENDER, address(payments), true);
        // Allow token as reserve token (STATUS = 2)
        treasury.setPermission(Treasury.STATUS.RESERVETOKEN, address(token), true);
        vm.stopPrank();

        // Give user tokens and deposit to payments
        vm.startPrank(user);
        token.faucet();
        token.approve(address(payments), ONE_TOKEN * 300);
        payments.deposit(ONE_TOKEN * 300);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        TIERED USAGE COMPUTATION
    //////////////////////////////////////////////////////////////*/

    function test_computeCostSpanningMultipleTiers() public {
        // Provider tiers:
        //   Tier 1: up to 100 units cost = 1 per unit
        //   Tier 2: from 101 to 200 units cost = 2 per unit
        // Fallback rate = 3 per unit.
        // Apply 150 usage units.
        // Expected base cost = 100*1 + 50*2 = 200.
        // Royalty = 1% of 200 = 2; Provider share = 198.

        uint256 providerBalanceBefore = payments.getProviderBalance(provider);
        uint256 royaltyBefore = payments.getKonduxRoyaltyBalance();

        // Grant UPDATER_ROLE to owner
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // User deposits more to cover usage
        vm.startPrank(user);
        token.approve(address(payments), 200);
        payments.deposit(200);
        vm.stopPrank();

        vm.prank(owner);
        payments.applyUsage(user, provider, 150);

        // Check balances
        KonduxTieredPayments.UserPayment memory userPayment = payments.getUserPayment(user);
        assertEq(userPayment.totalUsed, 200, "Total used should be 200");

        uint256 providerBalance = payments.getProviderBalance(provider);
        assertEq(providerBalance, providerBalanceBefore + 198, "Provider should receive 198");

        uint256 royaltyBalance = payments.getKonduxRoyaltyBalance();
        assertEq(royaltyBalance, royaltyBefore + 2, "Royalty should be 2");
    }

    function test_billExactlyOnThreshold() public {
        // Apply exactly 100 usage units.
        // Expected cost = 100 * 1 = 100, with royalty = 1% of 100 = 1.

        // Re-register provider to reset state
        vm.prank(provider);
        payments.registerProvider(0, 3);

        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // User deposits more
        vm.startPrank(user);
        token.approve(address(payments), 100);
        payments.deposit(100);
        vm.stopPrank();

        vm.prank(owner);
        payments.applyUsage(user, provider, 100);

        KonduxTieredPayments.UserPayment memory userPayment = payments.getUserPayment(user);
        assertEq(userPayment.totalUsed, 100, "Total used should be 100");

        uint256 providerBalance = payments.getProviderBalance(provider);
        assertEq(providerBalance, 99, "Provider should receive 99 after royalty");
    }

    /*//////////////////////////////////////////////////////////////
                        TIME-LOCK AND WITHDRAWALS
    //////////////////////////////////////////////////////////////*/

    function test_revertWithdrawalBeforeLockExpires() public {
        // Try withdrawUnused immediately should revert
        vm.prank(user);
        vm.expectRevert("Deposit still locked");
        payments.withdrawUnused();
    }

    function test_allowWithdrawalAfterLockExpires() public {
        // Advance time by lock period + 1 second
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        KonduxTieredPayments.UserPayment memory paymentBefore = payments.getUserPayment(user);
        assertEq(paymentBefore.totalDeposited, ONE_TOKEN * 300, "Should have 300 tokens deposited");

        // Withdrawal should succeed
        vm.prank(user);
        payments.withdrawUnused();

        KonduxTieredPayments.UserPayment memory paymentAfter = payments.getUserPayment(user);
        assertEq(paymentAfter.totalDeposited, paymentAfter.totalUsed, "Deposit should equal used after withdrawal");
    }

    /*//////////////////////////////////////////////////////////////
                            NFT DISCOUNT
    //////////////////////////////////////////////////////////////*/

    function test_applyNFTDiscountIfUserHoldsNFT() public {
        // Mint NFT for user
        vm.prank(owner);
        mockNFT.safeMint(user, 0);

        assertEq(mockNFT.balanceOf(user), 1, "User should have 1 NFT");

        // Set NFT discount to 20% (2000 BPS)
        vm.prank(governor);
        payments.setNFTDiscountBps(2000);

        // Verify user has NFT
        assertTrue(payments.userHasAnyNFT(user), "User should have NFT");

        // Grant UPDATER_ROLE
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // User deposits more
        vm.startPrank(user);
        token.approve(address(payments), 10);
        payments.deposit(10);
        vm.stopPrank();

        // Apply 10 usage units
        vm.prank(owner);
        payments.applyUsage(user, provider, 10);

        KonduxTieredPayments.UserPayment memory userPayment = payments.getUserPayment(user);
        // Expected base cost = 10*1 = 10; discount = 10*20% = 2; discountedCost = 8
        assertEq(userPayment.totalUsed, 8, "Total used should be 8 after 20% discount");
    }

    function test_shortCircuitUsageIfNFTDiscountRendersZero() public {
        // Set 100% discount
        vm.prank(governor);
        payments.setNFTDiscountBps(10000);

        // Mint NFT for user
        vm.prank(owner);
        mockNFT.safeMint(user, 0);

        // Grant UPDATER_ROLE
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Apply usage - should emit event with 0 cost
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit KonduxTieredPayments.UsageApplied(user, provider, 0, 0);
        payments.applyUsage(user, provider, 50);

        // Payment should remain unchanged
        KonduxTieredPayments.UserPayment memory userPayment = payments.getUserPayment(user);
        assertEq(userPayment.totalUsed, 0, "Total used should remain 0");
    }

    /*//////////////////////////////////////////////////////////////
                        ORACLE USAGE OVERRIDE
    //////////////////////////////////////////////////////////////*/

    function test_useOracleUsageIfHigherThanLocal() public {
        // Grant UPDATER_ROLE
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Apply some usage locally (cost = 50)
        vm.prank(owner);
        payments.applyUsage(user, provider, 50);

        // Set oracle to return higher usage
        usageOracle.setUsage(user, 80);

        // Advance time for withdrawal
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Withdraw - contract compares local (50) with oracle (80), uses higher
        vm.prank(user);
        payments.withdrawUnused();

        KonduxTieredPayments.UserPayment memory paymentAfter = payments.getUserPayment(user);
        assertEq(paymentAfter.totalDeposited, paymentAfter.totalUsed, "Deposit should equal used");
    }

    function test_notOverrideIfOracleUsageLowerThanLocal() public {
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        KonduxTieredPayments.UserPayment memory initialPayment = payments.getUserPayment(user);
        uint256 LOCAL_USAGE = 50;

        // Local usage = 50
        vm.prank(owner);
        payments.applyUsage(user, provider, LOCAL_USAGE);

        // Oracle usage = 30 (lower)
        usageOracle.setUsage(user, 30);

        // Advance time
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Expected leftover = deposit - local usage
        uint256 expectedLeftover = initialPayment.totalDeposited - initialPayment.totalUsed - LOCAL_USAGE;

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit KonduxTieredPayments.UnusedWithdrawn(user, address(token), expectedLeftover);
        payments.withdrawUnused();
    }

    function test_behaviorWithoutOracle() public {
        // Remove the oracle
        vm.prank(governor);
        payments.setUsageOracle(address(0));

        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        KonduxTieredPayments.UserPayment memory initialPayment = payments.getUserPayment(user);
        uint256 LOCAL_USAGE = 100;

        // Apply local usage
        vm.prank(owner);
        payments.applyUsage(user, provider, LOCAL_USAGE);

        // Advance time
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Leftover = 300 - 100 = 200 (in tokens, scaled)
        uint256 expectedLeftover = initialPayment.totalDeposited - initialPayment.totalUsed - LOCAL_USAGE;

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit KonduxTieredPayments.UnusedWithdrawn(user, address(token), expectedLeftover);
        payments.withdrawUnused();
    }

    /*//////////////////////////////////////////////////////////////
                    GOVERNOR-ONLY ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_governorCanUpdateAcceptedToken() public {
        // Deploy another token
        vm.prank(owner);
        KonduxERC20 token2 = new KonduxERC20();

        // Non-governor should revert
        vm.prank(user);
        vm.expectRevert();
        payments.setTokenAccepted(address(token2));

        // Governor can set
        vm.prank(governor);
        payments.setTokenAccepted(address(token2));
        assertEq(payments.token(), address(token2), "Token should be updated");

        // Governor can revert back
        vm.prank(governor);
        payments.setTokenAccepted(address(token));
        assertEq(payments.token(), address(token), "Token should be reverted");
    }

    function test_governorCanUpdateLockPeriod() public {
        uint256 newLockPeriod = 7200; // 2 hours

        // Non-governor revert
        vm.prank(user);
        vm.expectRevert();
        payments.setLockPeriod(newLockPeriod);

        // Governor success
        vm.prank(governor);
        payments.setLockPeriod(newLockPeriod);
        assertEq(payments.lockPeriod(), newLockPeriod, "Lock period should be updated");
    }

    function test_governorCanUpdateDefaultRoyaltyBps() public {
        uint256 newRoyaltyBps = 300; // 3%

        vm.prank(user);
        vm.expectRevert();
        payments.setDefaultRoyaltyBps(newRoyaltyBps);

        vm.prank(governor);
        payments.setDefaultRoyaltyBps(newRoyaltyBps);
        assertEq(payments.defaultRoyaltyBps(), newRoyaltyBps, "Royalty BPS should be updated");
    }

    function test_governorCanUpdateKonduxRoyaltyAddress() public {
        // Non-governor revert
        vm.prank(user);
        vm.expectRevert();
        payments.setKonduxRoyaltyAddress(user);

        // Zero address should revert
        vm.prank(governor);
        vm.expectRevert("Invalid royalty address");
        payments.setKonduxRoyaltyAddress(address(0));

        // Valid address succeeds
        vm.prank(governor);
        payments.setKonduxRoyaltyAddress(other);
        assertEq(payments.konduxRoyaltyAddress(), other, "Royalty address should be updated");
    }

    /*//////////////////////////////////////////////////////////////
                        PROVIDER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_providerUnregisterAndEffects() public {
        // Grant UPDATER_ROLE
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Re-register and set tiers
        vm.startPrank(provider);
        payments.registerProvider(0, 3);
        uint256[] memory thresholds = new uint256[](2);
        thresholds[0] = 100;
        thresholds[1] = 200;
        uint256[] memory costs = new uint256[](2);
        costs[0] = 1;
        costs[1] = 2;
        payments.setProviderTiers(thresholds, costs);
        vm.stopPrank();

        // Apply usage so provider has balance
        vm.prank(owner);
        payments.applyUsage(user, provider, 50);

        uint256 providerBalBefore = payments.getProviderBalance(provider);
        assertTrue(providerBalBefore > 0, "Provider should have balance");

        // Unregister - this should also withdraw balance
        vm.prank(provider);
        payments.unregisterProvider();

        // Provider balance should be 0 (withdrawn)
        assertEq(payments.getProviderBalance(provider), 0, "Provider balance should be 0");

        // Provider info should be cleared
        KonduxTieredPayments.ProviderInfo memory providerInfo = payments.getProviderInfo(provider);
        assertFalse(providerInfo.registered, "Provider should not be registered");
        assertEq(providerInfo.royaltyBps, 0, "Royalty BPS should be 0");
        assertEq(providerInfo.fallbackRate, 0, "Fallback rate should be 0");

        // Tiers should be deleted
        KonduxTieredPayments.Tier[] memory tiersAfter = payments.getProviderTiers(provider);
        assertEq(tiersAfter.length, 0, "Tiers should be empty");
    }

    function test_revertNonAscendingThresholds() public {
        // Attempt to set thresholds [100, 90] which is not ascending
        vm.prank(provider);
        vm.expectRevert("Thresholds not ascending");
        uint256[] memory thresholds = new uint256[](2);
        thresholds[0] = 100;
        thresholds[1] = 90;
        uint256[] memory costs = new uint256[](2);
        costs[0] = 1;
        costs[1] = 2;
        payments.setProviderTiers(thresholds, costs);
    }

    function test_revertMismatchedArrayLengths() public {
        vm.prank(provider);
        vm.expectRevert("Tier array mismatch");
        uint256[] memory thresholds = new uint256[](2);
        thresholds[0] = 100;
        thresholds[1] = 200;
        uint256[] memory costs = new uint256[](1);
        costs[0] = 1;
        payments.setProviderTiers(thresholds, costs);
    }

    function test_allowEmptyTiers() public {
        // Some providers might want to use only fallbackRate
        vm.prank(provider);
        uint256[] memory emptyThresholds = new uint256[](0);
        uint256[] memory emptyCosts = new uint256[](0);
        payments.setProviderTiers(emptyThresholds, emptyCosts);

        KonduxTieredPayments.Tier[] memory tiers = payments.getProviderTiers(provider);
        assertEq(tiers.length, 0, "Tiers should be empty");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE AND FAILURE CASES
    //////////////////////////////////////////////////////////////*/

    function test_revertInsufficientDeposit() public {
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Withdraw user's deposit first
        vm.warp(block.timestamp + LOCK_PERIOD + 1);
        vm.prank(user);
        payments.withdrawUnused();

        // Deposit only 10 tokens
        vm.startPrank(user);
        token.approve(address(payments), 10);
        payments.deposit(10);
        vm.stopPrank();

        // Try to apply usage that costs more than 10
        vm.prank(owner);
        vm.expectRevert("Insufficient deposit for usage");
        payments.applyUsage(user, provider, 50);
    }

    function test_revertDepositZeroTokens() public {
        vm.prank(user);
        vm.expectRevert("Deposit must be > 0");
        payments.deposit(0);
    }

    function test_revertProviderWithdrawWithoutBalance() public {
        // Register new provider with no usage
        vm.prank(other);
        payments.registerProvider(0, 2);

        // Try to withdraw
        vm.prank(other);
        vm.expectRevert("No balance to withdraw");
        payments.providerWithdraw();
    }

    function test_revertRoyaltyWithdrawalByNonAuthorized() public {
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Apply usage to create royalty
        vm.prank(owner);
        payments.applyUsage(user, provider, 100);

        // Attempt by random user
        vm.prank(user);
        vm.expectRevert("Only Kondux can withdraw royalty");
        payments.withdrawRoyalty();
    }

    function test_revertApplyZeroUsage() public {
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        vm.prank(owner);
        vm.expectRevert("Usage must be > 0");
        payments.applyUsage(user, provider, 0);
    }

    function test_selfApplyUsage() public {
        vm.prank(user);
        payments.selfApplyUsage(provider, 50);

        KonduxTieredPayments.UserPayment memory userPayment = payments.getUserPayment(user);
        assertEq(userPayment.totalUsed, 50, "Total used should be 50");
    }

    function test_validRoyaltyWithdrawal() public {
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        // Generate royalty
        vm.prank(owner);
        payments.applyUsage(user, provider, 100); // cost=100 => royalty=1

        uint256 royaltyBalance = payments.getKonduxRoyaltyBalance();
        assertEq(royaltyBalance, 1, "Royalty should be 1");

        // Confirm royaltyAddress is governor
        assertEq(payments.konduxRoyaltyAddress(), governor, "Royalty address should be governor");

        // Governor withdraws
        vm.prank(governor);
        vm.expectEmit(true, false, false, true);
        emit KonduxTieredPayments.RoyaltyWithdrawn(address(token), 1);
        payments.withdrawRoyalty();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_isLockedReturnsCorrectly() public {
        assertTrue(payments.isLocked(user), "Should be locked initially");

        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        assertFalse(payments.isLocked(user), "Should be unlocked after period");
    }

    function test_getLeftoverBalance() public {
        uint256 leftover = payments.getLeftoverBalance(user);
        assertEq(leftover, ONE_TOKEN * 300, "Leftover should equal deposit");

        // Apply some usage
        vm.prank(governor);
        payments.grantRole(UPDATER_ROLE, owner);

        vm.prank(owner);
        payments.applyUsage(user, provider, 50);

        leftover = payments.getLeftoverBalance(user);
        assertEq(leftover, ONE_TOKEN * 300 - 50, "Leftover should be deposit minus usage");
    }

    function test_getNFTContracts() public view {
        address[] memory nfts = payments.getNFTContracts();
        assertEq(nfts.length, 1, "Should have 1 NFT contract");
        assertEq(nfts[0], address(mockNFT), "NFT contract should be mockNFT");
    }
}
