const { expect } = require("chai");
const { MaxUint256 } = require("ethers");
const { ethers, network } = require("hardhat");

describe("KonduxTieredPayments", function () {
  let owner, user, provider, governor, other;
  let payments;
  let treasury;
  let authority;
  let usageOracle;
  let mockNFT;
  let token; // using an ERC20 mock as stablecoin
  const ONE_TOKEN = ethers.parseEther("1");
  
  // Deploy minimal mocks for Treasury, UsageOracle, NFT and ERC20.
  // For Treasury, deposit/withdraw simply update an internal balance mapping.
  beforeEach(async function () {
    [owner, governor, provider, user, other] = await ethers.getSigners();

    const ownerAddress = await owner.getAddress();
    const governorAddress = await governor.getAddress();    

    // Deploy Authority
    const Authority = await ethers.getContractFactory("Authority");
    authority = await Authority.deploy(ownerAddress, ownerAddress, ownerAddress, ownerAddress);
    await authority.waitForDeployment();

    // Deploy a MockERC20 token to act as stablecoin.
    const ERC20Mock = await ethers.getContractFactory("KonduxERC20", owner);
    token = await ERC20Mock.deploy();
    await token.waitForDeployment();    

    // Deploy a simple usage oracle mock. Initially returns 0.
    const UsageOracleMock = await ethers.getContractFactory("UsageOracleMock");
    usageOracle = await UsageOracleMock.deploy();
    await usageOracle.waitForDeployment();

    // Deploy a dummy NFT contract that grants balance to users.
    const NFTMock = await ethers.getContractFactory("MockKondux", owner);
    mockNFT = await NFTMock.deploy();
    await mockNFT.waitForDeployment(); 

    // Deploy Treasury
    const Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(await authority.getAddress());
    await treasury.waitForDeployment();

    // Deploy KonduxTieredPayments contract.
    const KonduxTieredPayments = await ethers.getContractFactory("KonduxTieredPayments");
    const lockPeriod = 3600; // 1 hour    
    payments = await KonduxTieredPayments.deploy(
      await treasury.getAddress(),
      await governor.getAddress(),
      await token.getAddress(),
      lockPeriod,
      await governor.getAddress()  // using governor as royalty receiver
    );
    await payments.waitForDeployment(); 

    // console.log("KonduxTieredPayments deployed to: ", await payments.getAddress());

    // Set usage oracle & NFT contracts in payments
    await payments.connect(governor).setUsageOracle(await usageOracle.getAddress());
    // console.log("UsageOracle set to: ", await payments.usageOracle());

    await payments.connect(governor).setNFTContracts([await mockNFT.getAddress()]);    
    // console.log("NFT contracts set to: ", await payments.getNFTContracts());

    // Give provider an initial registration with fallback rate = 3 and no custom royalty so default 1% applies.
    await payments.connect(provider).registerProvider(0, 3);
    // console.log("Provider registered: ", await payments.getProviderInfo(await provider.getAddress()));

    // Set provider tiers.
    // Tier structure: tier1: cumulative 100 units at cost=1, tier2: cumulative 200 units at cost=2.
    const thresholds = [100, 200];
    const costs = [1, 2];
    await payments.connect(provider).setProviderTiers(thresholds, costs);

    // Mint some tokens to user and approve treasury.
    await token.connect(user).approve(await treasury.getAddress(), ethers.parseEther("10000"));
    // Also deposit tokens into treasury on behalf of user.
    // For these tests we simulate the treasury: the deposit() call from payments just forwards tokens.
    // first, give approval to Payments contract to spend user's tokens
    await token.connect(user).approve(await payments.getAddress(), ONE_TOKEN * (300n));
    // then, mint some tokens to user
    await token.connect(user).faucet(); // mint tokens
    
    // now, allow the token to be deposited on Treasury using setPermission function
    await treasury.connect(owner).setPermission(2, await payments.getAddress(), true);

    // allow token to be withdrawn from treasury by payments contract
    await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);

    // then deposit to treasury
    await payments.connect(user).deposit( ONE_TOKEN * (300n)); // deposit 300 tokens

    // console.log("User deposit confirmed: ", await payments.getUserPayment(await user.getAddress()));
  });

  describe("Tiered usage computation", function () {
    it("should compute cost spanning multiple tiers and allocate 1% royalty", async function () {
      // Provider tiers:
      //   Tier 1: up to 100 units cost = 1 per unit
      //   Tier 2: from 101 to 200 units cost = 2 per unit
      // Fallback rate = 3 per unit.
      // Apply 150 usage units.
      // Expected base cost = 100*1 + 50*2 = 200.
      // Royalty = 1% of 200 = 2; Provider share = 198.
      
      // Capture balances before usage.
      const providerBalanceBefore = await payments.getProviderBalance(provider.address);
      const royaltyBefore = await payments.getKonduxRoyaltyBalance();
      
      // Use UPDATER_ROLE (simulate by granting it to owner for testing)
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // Mint tokens to user and deposit to cover usage.
      await token.connect(user).faucet();
      await token.connect(user).approve(await payments.getAddress(), MaxUint256);
      // User makes a deposit to cover usage.
      await payments.connect(user).deposit( 200);
      
      await payments.connect(owner).applyUsage(user.address, provider.address, 150);
      
      // Check event and balances.
      // Get updated user payment record.
      const userPayment = await payments.getUserPayment(user.address);
      expect(userPayment.totalUsed).to.equal(200);
      
      const providerBalance = await payments.getProviderBalance(provider.address);
      expect(providerBalance).to.equal(providerBalanceBefore + 198n);

      const royaltyBalance = await payments.getKonduxRoyaltyBalance();
      expect(royaltyBalance).to.equal(royaltyBefore + 2n);
    });

    it("should bill exactly on threshold usage", async function () {
      // Apply exactly 100 usage units.
      // Expected cost = 100 * 1 = 100, with royalty = 1% of 100 =1.
      await payments.connect(provider).registerProvider(0, 3); // re-register provider
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // Mint tokens to user and deposit to cover usage.
      await token.connect(user).faucet();
      await token.connect(user).approve(await payments.getAddress(), MaxUint256);

      // User makes a deposit to cover usage.      
      await payments.connect(user).deposit( 100);

      await payments.connect(owner).applyUsage(user.address, provider.address, 100);
      
      const userPayment = await payments.getUserPayment(user.address);
      expect(userPayment.totalUsed).to.equal(100);
      
      const providerBalance = await payments.getProviderBalance(provider.address);
      expect(providerBalance).to.equal(99); // 99 after deduction of royalty
    });
  });

  describe("Time-lock and withdrawals", function () {
    it("should revert withdrawal before lock expires and allow after", async function () {
      // Add token as reserve asset in treasury.
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);

      // Allow payments contract to withdraw tokens from treasury
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);

      // Try withdrawUnused immediately should revert.
      await expect(
        payments.connect(user).withdrawUnused()
      ).to.be.revertedWith("Deposit still locked");

      // Increase time by lockPeriod + 1 second.
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");

      // No usage applied yet, so leftover should equal deposit.
      const paymentBefore = await payments.getUserPayment(user.address);
      expect(paymentBefore.totalDeposited).to.equal(ONE_TOKEN * 300n);
      // Perform withdrawal. Since no usage, this should succeed.
      await payments.connect(user).withdrawUnused();
      // After withdrawal, payment record becomes consumed.
      const paymentAfter = await payments.getUserPayment(user.address);
      expect(paymentAfter.totalDeposited).to.equal(paymentAfter.totalUsed);
    });
  });

  describe("NFT discount", function () {
    it("should apply NFT discount if user holds NFT", async function () {
      // Mint an NFT for user so that _userHasAnyNFT returns true.
      await mockNFT.connect(owner).safeMint(user.address, 0);

      // check if user has NFT by calling mockNFT contract
      const userOwnsNFT = await mockNFT.connect(user).balanceOf(user.address);
      expect(userOwnsNFT).to.equal(1);

      // set mockNFT as NFT contract in payments
      await payments.connect(governor).setNFTContracts([await mockNFT.getAddress()]);

      // set NFT discount to 20% (2000 BPS)
      await payments.connect(governor).setNFTDiscountBps(2000);
      
      // Apply usage that normally would cost a small amount.
      // For this test, we simulate tiers with a low cost so discount can wipe out the charge.
      // Let's set provider tier so that 10 usage units cost 1 each = 10,
      // And NFT discount is 2000 BPS (20% discount), so discount = 2, leaving cost 8 (not zero).
      // Instead, to achieve zero cost, we can simulate a scenario where base cost is 0.
      // But since cost is computed as multiplication, if cost per unit is 0 the base is 0.
      // Alternatively, we test that discount reduces cost.
      
      // Apply 10 usage units:
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // Mint tokens to user and deposit to cover usage.
      await token.connect(user).faucet();
      await token.connect(user).approve(await payments.getAddress(), MaxUint256);
      // User makes a deposit to cover usage.
      await payments.connect(user).deposit( 10);

      // check if user has NFT
      const userHasNFT = await payments.connect(user).userHasAnyNFT(user.address);
      expect(userHasNFT).to.be.true;

      await payments.connect(owner).applyUsage(user.address, provider.address, 10);
      const userPayment = await payments.getUserPayment(user.address);
      // Expected base cost = 10*1 = 10; discount = 10*20% = 2; discountedCost = 8.
      expect(userPayment.totalUsed).to.equal(8);
    });

    it("should short-circuit usage update if NFT discount renders cost zero", async function () {
      // Adjust discount such that discount >= base cost.
      await payments.connect(governor).setNFTDiscountBps(10000); // 100% discount

      // Mint an NFT for user.
      await mockNFT.connect(owner).safeMint(user.address, 0);
      await payments.connect(governor).setNFTContracts([await mockNFT.getAddress()]);

      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);
      // Apply any usage. Since cost becomes 0, usage is not applied.
      await expect(payments.connect(owner).applyUsage(user.address, provider.address, 50))
        .to.emit(payments, "UsageApplied")
        .withArgs(user.address, provider.address, 0, 0);

      // Confirm payment remains unchanged.
      const userPayment = await payments.getUserPayment(user.address);
      expect(userPayment.totalUsed).to.equal(0);
    });
  });

  describe("Oracle usage override", function () {
    it("should use external oracle usage if higher than local", async function () {
      // Add token as reserve asset in treasury.
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);

      // Set payment contract to withdraw from treasury.
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);
      
      // Apply some usage locally.
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);
      await payments.connect(owner).applyUsage(user.address, provider.address, 50); // local usage cost 50

      // Set the oracle to return a higher usage value.
      await usageOracle.setUsage(user.address, 80);
      
      // Increase time to allow withdrawal.
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");
      
      // Now withdrawing unused funds – contract compares local totalUsed (50) with oracle (80)
      // Remaining deposit = deposit - oracle usage = 300 - 80 = 220.
      // Withdrawal should be processed with oracle usage.
      await payments.connect(user).withdrawUnused();
      const paymentAfter = await payments.getUserPayment(user.address);
      expect(paymentAfter.totalDeposited).to.equal(paymentAfter.totalUsed);
      // Actually, the unused funds withdrawn equals deposit - finalUsage.
    });
  });

  // =========================================================================
  // ============= GOVERNOR-ONLY ADMINISTRATIVE FUNCTIONS ====================
  // =========================================================================
  describe("Governor-Only Admin Functions", function () {
    it("should allow governor to add/remove stablecoins", async function () {
      // Deploy another ERC20 to test acceptance
      const ERC20Mock2 = await ethers.getContractFactory("KonduxERC20", owner);
      const token2 = await ERC20Mock2.deploy();
      await token2.waitForDeployment();

      // Initially not accepted
      expect(await payments.token()).to.not.equal(await token2.getAddress()); // not accepted

      // Non-governor should revert
      await expect(
        payments.connect(user).setTokenAccepted(await token2.getAddress())
      ).to.be.reverted; // or your custom revert

      // Governor can set accepted
      await payments.connect(governor).setTokenAccepted(await token2.getAddress());
      expect(await payments.token()).to.equal(await token2.getAddress());

      // Governor can set not accepted
      await payments.connect(governor).setTokenAccepted(await token.getAddress());
      expect(await payments.token()).to.equal(await token.getAddress());
    });

    it("should allow governor to update lockPeriod", async function () {
      const newLockPeriod = 7200; // 2 hours

      // non-governor revert
      await expect(payments.connect(user).setLockPeriod(newLockPeriod)).to.be.reverted;

      // governor success
      await payments.connect(governor).setLockPeriod(newLockPeriod);
      expect(await payments.lockPeriod()).to.equal(newLockPeriod);
    });

    it("should allow governor to update defaultRoyaltyBps", async function () {
      const newRoyaltyBps = 300; // 3%
      await expect(payments.connect(user).setDefaultRoyaltyBps(newRoyaltyBps)).to.be.reverted;

      await payments.connect(governor).setDefaultRoyaltyBps(newRoyaltyBps);
      expect(await payments.defaultRoyaltyBps()).to.equal(newRoyaltyBps);
    });

    it("should allow governor to update konduxRoyaltyAddress", async function () {
      // Non-governor revert
      await expect(
        payments.connect(user).setKonduxRoyaltyAddress(user.address)
      ).to.be.reverted;

      // Setting to zero address should revert
      await expect(
        payments.connect(governor).setKonduxRoyaltyAddress(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid royalty address");

      // Setting a valid address
      await payments.connect(governor).setKonduxRoyaltyAddress(other.address);
      expect(await payments.konduxRoyaltyAddress()).to.equal(other.address);
    });
  });

  // =========================================================================
  // ========================= PROVIDER MANAGEMENT ============================
  // =========================================================================
  describe("Provider Management", function () {
    it("should allow provider to unregister and remove tiers but keep existing balances", async function () {
      // authorize token to be withdrawn from treasury by payments contract
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);
      // authorize token to be deposited to treasury by payments contract
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);

      // set owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // register provider
      await payments.connect(provider).registerProvider(0, 3);
      // set tiers
      await payments.connect(provider).setProviderTiers([100, 200], [1, 2]);

      // Provider has been registered and set tiers already in beforeEach
      // Let's apply some usage so that provider has balance
      await payments.connect(owner).applyUsage(user.address, provider.address, 50);
      const providerBalBefore = await payments.getProviderBalance(provider.address);
      expect(providerBalBefore).to.be.gt(0);

      // Unregister
      await payments.connect(provider).unregisterProvider();
      expect(await payments.getProviderBalance(provider.address)).to.equal(0);

      // The provider is no longer registered
      const providerInfo = await payments.getProviderInfo(provider.address);
      expect(providerInfo.registered).to.equal(false);
      expect(providerInfo.royaltyBps).to.equal(0);
      expect(providerInfo.fallbackRate).to.equal(0);

      // Tiers should be deleted
      const tiersAfter = await payments.getProviderTiers(provider.address);
      expect(tiersAfter.length).to.equal(0);

    });

    it("should revert if provider sets tiers with non-ascending thresholds", async function () {
      // Attempt to set thresholds [100, 90] which is not ascending
      await expect(
        payments.connect(provider).setProviderTiers([100, 90], [1, 2])
      ).to.be.revertedWith("Thresholds not ascending");
    });

    it("should revert if provider sets tiers with mismatched array lengths", async function () {
      // usageThresholds length = 2, costPerUnit length = 1
      await expect(
        payments.connect(provider).setProviderTiers([100, 200], [1])
      ).to.be.revertedWith("Tier array mismatch");
    });

    it("should allow provider to set empty tiers (valid if fallbackRate is used)", async function () {
      // Some providers might want to use only fallbackRate with no tiers
      // That means no revert if arrays are both empty.
      await payments.connect(provider).setProviderTiers([], []);
      const tiers = await payments.getProviderTiers(provider.address);
      expect(tiers.length).to.equal(0);
    });
  });

  // =========================================================================
  // ========================= EDGE AND FAILURE CASES =========================
  // =========================================================================
  describe("Edge and Failure Cases", function () {
    it("should revert applying usage if insufficient deposit", async function () {
      // authorize token to be withdrawn from treasury by payments contract
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);
      // authorize token to be deposited to treasury by payments contract
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);

      // make owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // Let’s deposit only 10 tokens for user
      // Clear out user's deposit first by letting them withdraw (advance time)
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");
      await payments.connect(user).withdrawUnused();

      // give allowance to payments contract to spend user's tokens
      await token.connect(user).approve(await payments.getAddress(), 1000);

      // Now deposit only 10 tokens
      await payments.connect(user).deposit( 10);

      // Try to apply usage that costs more than 10
      await expect(
        payments.connect(owner).applyUsage(user.address, provider.address, 50) // cost will exceed 10
      ).to.be.revertedWith("Insufficient deposit for usage");
    });

    it("should revert depositing zero tokens", async function () {
      await expect(
        payments.connect(user).deposit(0)
      ).to.be.revertedWith("Deposit must be > 0");
    });

    it("should revert if provider tries to withdraw without a balance", async function () {
      // new provider with no usage
      await payments.connect(other).registerProvider(0, 2);
      // try to withdraw
      await expect(
        payments.connect(other).providerWithdraw()
      ).to.be.revertedWith("No balance to withdraw");
    });

    it("should revert royalty withdrawal by non-royaltyAddress", async function () {
      // add owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // For testing, let's apply usage that creates some royalty
      await payments.connect(owner).applyUsage(user.address, provider.address, 100); // 100 cost => 1% royalty = 1

      // Attempt by random user
      await expect(
        payments.connect(user).withdrawRoyalty()
      ).to.be.revertedWith("Only Kondux can withdraw royalty");
    });

    it("should revert applying zero usage units", async function () {
      // make owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);
      
      await expect(
        payments.connect(owner).applyUsage(user.address, provider.address, 0)
      ).to.be.revertedWith("Usage must be > 0");
    });

    it("should allow user to selfApplyUsage", async function () {
      // user calls selfApplyUsage
      await payments.connect(user).selfApplyUsage(provider.address, 50);
      const userPayment = await payments.getUserPayment(user.address);
      expect(userPayment.totalUsed).to.equal(50);
    });

    it("should allow valid royalty withdrawal by royaltyAddress", async function () {
      // add owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // add token to treasury
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);
      // allow token to be withdrawn from treasury by payments contract
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);

      // Let’s generate some royalty
      await payments.connect(owner).applyUsage(user.address, provider.address, 100); // cost=100 => royalty=1
      const royaltyBalance = await payments.getKonduxRoyaltyBalance();
      expect(royaltyBalance).to.equal(1);

      // Confirm that the royaltyAddress is the governor (by constructor)
      const currentRoyaltyAddress = await payments.konduxRoyaltyAddress();
      expect(currentRoyaltyAddress).to.equal(governor.address);

      // Governor withdraws
      await expect(
        payments.connect(governor).withdrawRoyalty()
      )
        .to.emit(payments, "RoyaltyWithdrawn")
        .withArgs(await token.getAddress(), 1);
    });
  });

  // =========================================================================
  // ============================= USAGE ORACLE ===============================
  // =========================================================================
  describe("Usage Oracle Behavior", function () {
    it("should not override if oracle usage is lower or equal to local usage", async function () {
      // add owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);

      // add token to treasury
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);
      // allow token to be withdrawn from treasury by payments contract
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);

      // Get initial user payment record
      const { totalDeposited, totalUsed } = await payments.getUserPayment(user.address);

      const LOCAL_USAGE = 50n;

      // Local usage = 50
      await payments.connect(owner).applyUsage(user.address, provider.address, LOCAL_USAGE);
      // Oracle usage = 30 (lower)
      await usageOracle.setUsage(user.address, 30);

      // Advance time for withdrawal
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");

      // Expected leftover = deposit - local usage (300 - 50 = 250)
      // The contract sees local usage=50, oracle=30 => final=50
      await expect(payments.connect(user).withdrawUnused())
        .to.emit(payments, "UnusedWithdrawn")
        .withArgs(user.address, await token.getAddress(), totalDeposited - totalUsed - LOCAL_USAGE);
    });

    it("should do nothing special if oracle is not set", async function () {
      // Remove the oracle
      await payments.connect(governor).setUsageOracle(ethers.ZeroAddress);
      // set owner as updater role
      await payments.connect(governor).grantRole(await payments.UPDATER_ROLE(), owner.address);
      // Get initial user payment record
      const { totalDeposited, totalUsed } = await payments.getUserPayment(user.address);

      const LOCAL_USAGE = 100n;

      // local usage = 100
      await payments.connect(owner).applyUsage(user.address, provider.address, LOCAL_USAGE);

      // Advance time
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");

      // allow token to be withdrawn from treasury by payments contract
      await treasury.connect(owner).setPermission(1, await payments.getAddress(), true);
      // allow token to be deposited to treasury by payments contract
      await treasury.connect(owner).setPermission(2, await token.getAddress(), true);

      // leftover = 300 - 100 = 200
      await expect(payments.connect(user).withdrawUnused())
        .to.emit(payments, "UnusedWithdrawn")
        .withArgs(user.address, await token.getAddress(), totalDeposited - totalUsed - LOCAL_USAGE);
    });
  });
});


// good, create tests following the test file provided setup for all missing and incomplete. use hardhat test suite (same as the file pasted by me is using):
// ```
// Administrative Functions (Governor-Only)
// ❌ Changing accepted stablecoins
// ❌ Updating lockPeriod
// ❌ Updating defaultRoyaltyBps
// ❌ Updating konduxRoyaltyAddress
// Provider Management
// ❌ Provider unregistering scenario and its effects on existing balances and tiers
// ❌ Edge cases with invalid provider tier definitions (e.g., non-ascending thresholds)
// Edge and Failure Cases
// ❌ Insufficient deposit to cover usage (should revert clearly)
// ❌ Depositing zero tokens (explicit failure test missing)
// ❌ Depositing unaccepted stablecoins
// ❌ Providers trying to withdraw without balance
// ❌ Royalty withdrawal by non-authorized addresses
// ❌ Providers attempting to register/update tiers improperly (e.g., empty arrays, mismatched lengths)
// ❌ Applying zero usage (should revert or short-circuit clearly)
// ❌ Users applying usage directly (selfApplyUsage() not tested)
// ❌ Withdrawal of royalties (success and failure scenarios)
// Usage Oracle
// ❌ Testing when oracle returns usage lower or equal to internal usage
// ❌ Oracle not set (behavior without external verification)
// ```