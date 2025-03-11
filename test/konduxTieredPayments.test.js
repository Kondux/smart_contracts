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
    const acceptedStablecoins = [await token.getAddress()];
    // console.log("Accepted stablecoins: ", acceptedStablecoins);
    const lockPeriod = 3600; // 1 hour
    payments = await KonduxTieredPayments.deploy(
      await treasury.getAddress(),
      await governor.getAddress(),
      acceptedStablecoins,
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

    // then deposit to treasury
    await payments.connect(user).deposit(await token.getAddress(), ONE_TOKEN * (300n)); // deposit 300 tokens

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
      await payments.connect(user).deposit(await token.getAddress(), 200);
      
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
      await payments.connect(user).deposit(await token.getAddress(), 100);

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
        payments.connect(user).withdrawUnused(await token.getAddress())
      ).to.be.revertedWith("Deposit still locked");

      // Increase time by lockPeriod + 1 second.
      await network.provider.send("evm_increaseTime", [3601]);
      await network.provider.send("evm_mine");

      // No usage applied yet, so leftover should equal deposit.
      const paymentBefore = await payments.getUserPayment(user.address);
      expect(paymentBefore.totalDeposited).to.equal(ONE_TOKEN * 300n);
      // Perform withdrawal. Since no usage, this should succeed.
      await payments.connect(user).withdrawUnused(await token.getAddress());
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
      await payments.connect(user).deposit(await token.getAddress(), 10);

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
      await payments.connect(user).withdrawUnused(await token.getAddress());
      const paymentAfter = await payments.getUserPayment(user.address);
      expect(paymentAfter.totalDeposited).to.equal(paymentAfter.totalUsed);
      // Actually, the unused funds withdrawn equals deposit - finalUsage.
    });
  });
});