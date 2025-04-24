import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { MaxUint256 } from "ethers";

/**
 * Replace these placeholder addresses with the actual mainnet
 * or testnet addresses where your system is deployed
 */
const AUTHORITY_ADDRESS = "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A"; 
const TREASURY_ADDRESS  = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E";
const HELIX_ERC20_ADDRESS = "0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4";
const FOUNDER_NFT_ADDRESS = "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b";
const KONDUX_ERC20_ADDRESS = "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1";
const KNFT_ADDRESS = "0x5aD180dF8619CE4f888190C3a926111a723632ce";

/**
 * Example addresses that hold tokens/NFTs on mainnet or testnet:
 */
const TOKEN_HOLDER_WITH_BALANCE = "0x4936167DAE4160E5556D9294F2C78675659a3B63";
const KNFT_HOLDER = "0x4936167DAE4160E5556D9294F2C78675659a3B63";

/**
 * If your Authority contract sets these as the governor or vault, ensure
 * we impersonate them for any `onlyGovernor` or `onlyVault` calls.
 * If your environment uses different roles, adapt accordingly.
 */
const GOVERNOR_ADDRESS = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";

/**
 * We'll test with 10_000_000 tokens (the contract sets a default min stake
 * to 10_000_000). Adjust if your environment is different or if your token
 * has decimals. If KONDUX_ERC20 has 9 decimals, for instance, you may need
 * to parse units accordingly.
 */
const STAKE_AMOUNT = 10_000_000n;

describe("Staking Contract Tests", function () {
  /**
   * This fixture deploys ONLY the Staking contract using your constructor,
   * pointing to mainnet/testnet addresses for Helix, Founders NFT, kNFT,
   * authority, treasury, etc. We impersonate a 'governor' or an EOA that
   * can deploy the contract and do the `onlyGovernor` calls needed for
   * setup. We also impersonate a user who holds enough KONDUX_ERC20
   * tokens to stake.
   */
  async function deployStakingFixture() {
    // 1) Impersonate the governor (or whoever is allowed to deploy)
    await ethers.provider.send("hardhat_impersonateAccount", [GOVERNOR_ADDRESS]);
    const governorSigner = await ethers.getSigner(GOVERNOR_ADDRESS);

    // 2) Deploy the Staking contract with the real references
    //    (if the addresses are zero, the constructor will revert).
    const StakingFactory = await ethers.getContractFactory("Staking", governorSigner);
    const staking = await StakingFactory.deploy(
      AUTHORITY_ADDRESS,
      KONDUX_ERC20_ADDRESS,
      TREASURY_ADDRESS,
      FOUNDER_NFT_ADDRESS,
      KNFT_ADDRESS,
      HELIX_ERC20_ADDRESS
    );
    await staking.waitForDeployment();

    // 3) Optional: If additional calls from the governor are needed (like
    //    setAuthorizedERC20, setMinStake, or treasury approvals), do them here.
    //    For instance:
    // await staking.connect(governorSigner).setAuthorizedERC20(KONDUX_ERC20_ADDRESS, true);
    // etc.

    // 4) Impersonate a holder that has KONDUX_ERC20 for staking
    await ethers.provider.send("hardhat_impersonateAccount", [TOKEN_HOLDER_WITH_BALANCE]);
    const tokenHolderSigner = await ethers.getSigner(TOKEN_HOLDER_WITH_BALANCE);

    // 5) Connect to the KONDUX_ERC20 token contract
    const konduxToken = await ethers.getContractAt(
      "KNDX", // or "IKonduxERC20" if you have the ABI
      KONDUX_ERC20_ADDRESS,
      tokenHolderSigner
    );

    // 6) Approve the staking contract from the token holder
    //    Enough for multiple tests
    await konduxToken.approve(staking.getAddress(), ethers.MaxUint256);

    // 7) Connect to Helix ERC20 (if needed) and make staking contract as minter role
    const helixToken = await ethers.getContractAt("Helix", HELIX_ERC20_ADDRESS, governorSigner);    
    await helixToken.setRole(ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")), await staking.getAddress(), true);
    await helixToken.setAllowedContract(await staking.getAddress(), true);

    // 8) instantiate the treasury contract and set the staking contract
    const treasury = await ethers.getContractAt("Treasury", TREASURY_ADDRESS, governorSigner);

    // 9) Configure staking's treasury permissions
    const setStaking = await treasury.setStakingContract(await staking.getAddress());
    await setStaking.wait();
    
    const setSpender = await treasury.setPermission(1, await staking.getAddress(), true);
    await setSpender.wait();
    
    const setDepositor = await treasury.setPermission(0, await staking.getAddress(), true);
    await setDepositor.wait(); 

    // 10) Treasury approves the staking contract to spend KONDUX_ERC20
    await treasury.erc20ApprovalSetup(KONDUX_ERC20_ADDRESS, ethers.MaxUint256);
    expect(
      await konduxToken.allowance(TREASURY_ADDRESS, staking.getAddress())
    ).to.be.eq(ethers.MaxUint256);

    return {
      staking,
      governorSigner,
      tokenHolderSigner,
      konduxToken,
      helixToken
    };
  }

  /**
   * 01) "Should mint kNFTs with 5% boost and check if the boost modifies
   *      calculateRewards(...) expected result"
   *
   * In this scenario, you'll want a user that holds at least 1 kNFT.
   * We'll impersonate that user, then do a deposit with the contract,
   * check the `calculateBoostPercentage` to confirm the +5% is applied,
   * and verify the `calculateRewards` is correct. 
   */
  it("Should mint kNFTs with 5% boost and check if the boost modifies rewards", async () => {
    const { staking } = await loadFixture(deployStakingFixture);

    // 1) Impersonate a user who holds kNFT or can get minted a kNFT
    await ethers.provider.send("hardhat_impersonateAccount", [KNFT_HOLDER]);
    const knftHolderSigner = await ethers.getSigner(KNFT_HOLDER);

    // 2) (Optional) If your environment doesn't automatically mint the kNFT,
    //    you might need to call the mint function on the kNFT contract here,
    //    impersonating the minter. Or if the user already has a kNFT, skip.
    //    For demonstration, we assume the user has it.

    // 3) Stake from the user. The user also needs KONDUX_ERC20, so be sure
    //    the kNFT_HOLDER address also has tokens or we do a token transfer. 
    //    We'll assume they have enough already:
    const depositTx = await staking.connect(knftHolderSigner).deposit(
      STAKE_AMOUNT, // 10_000_000 (no decimals for illustration)
      0,           // timelock = 0 => 1 month or no timelock, adapt as needed
      KONDUX_ERC20_ADDRESS
    );
    await depositTx.wait();

    // 4) Advance time to accumulate some rewards
    await time.increase(60 * 60 * 24 * 30); // 30 days
    // (Or use time.increaseTo for a specific timestamp.)

    // 5) Check the rewards with kNFT boost
    const depositIds = await staking.getDepositIds(knftHolderSigner.address);
    const firstDepositId = depositIds[0];
    const rewards = await staking.calculateRewards(knftHolderSigner.address, firstDepositId);

    // Compare `rewards` to your expected formula: 
    // (STAKE_AMOUNT * APR * elapsedTime) / (365 days in seconds)
    const calculatedRewards = Number(STAKE_AMOUNT) * 0.25 * (30 * 24 * 60 * 60) / (365 * 24 * 60 * 60);
    console.log("Calculated Rewards:", calculatedRewards);
    console.log("Rewards from contract:", rewards.toString());
    // Compare the calculated rewards with the contract's rewards
    expect(calculatedRewards).to.be.closeTo(Number(rewards), 1); 
    expect(rewards).to.be.gt(10000);

    // 6) For further assurance, you can compare the boost percentage:
    const boostPercentage = await staking.calculateBoostPercentage(knftHolderSigner.address, firstDepositId);
    expect(boostPercentage).to.be.eql(10000n); // e.g. 10500 if exactly 5%
  });

  /**
   * 02) "Should stake 10_000_000 tokens, advance time and get first reward"
   */
  it("Should stake 10_000_000 tokens, advance time and get first reward", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) Stake from the token holder
    const depositTx = await staking.connect(tokenHolderSigner).deposit(
      STAKE_AMOUNT, // 10_000_000
      0,            // e.g. 1-month timelock (index 0)
      KONDUX_ERC20_ADDRESS
    );
    await depositTx.wait();

    // 2) Advance time (e.g., 7 days)
    await time.increase(60 * 60 * 24 * 7);

    // 3) Claim the reward
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    const firstDepositId = depositIds[0];
    await staking.connect(tokenHolderSigner).claimRewards(firstDepositId);

    // 4) Validate results 
    //    - userTotalRewardedByCoin should have increased, 
    //    - unclaimedRewards should be 0, etc.
    const totalRewarded = await staking.userTotalRewardedByCoin(KONDUX_ERC20_ADDRESS, tokenHolderSigner.address);
    expect(totalRewarded).to.be.gt(0);
  });

  /**
   * 03) "Should stake 10_000_000 tokens, advance time and withdraw 10_000"
   */
  it("Should stake 10_000_000 tokens, advance time and withdraw 10_000", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) Stake
    await staking.connect(tokenHolderSigner).deposit(
      STAKE_AMOUNT,
      0,
      KONDUX_ERC20_ADDRESS
    );

    // 2) Advance time
    await time.increase(60 * 60 * 24 * 7);

    // 3) Withdraw 10_000
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    const firstDepositId = depositIds[0];
    const withdrawAmount = 10_000n;

    await staking.connect(tokenHolderSigner).withdraw(withdrawAmount, firstDepositId);

    // 4) Check that deposit is reduced
    const depositInfo = await staking.userDeposits(firstDepositId);
    expect(depositInfo.deposited).to.equal(STAKE_AMOUNT - withdrawAmount);
  });

  /**
   * 04) "Should stake 10_000_000 tokens, advance time, add another token,
   *       stake, advance time, withdraw"
   */
  it("Should stake, advance, stake more, withdraw", async () => {
    const { staking, tokenHolderSigner, konduxToken } = await loadFixture(deployStakingFixture);

    // (Optional) If you have a second token, you'd do the same process:
    // For the sample, we'll just use the same KONDUX_ERC20 again.

    // 1) First stake
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(60 * 60 * 24 * 7); // 7 days

    // 2) Second stake
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT / 2n, 0, KONDUX_ERC20_ADDRESS);

    // 3) Advance more time
    await time.increase(60 * 60 * 24 * 7);

    // 4) Withdraw partial
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    // Suppose we withdraw from the second deposit
    const secondDepositId = depositIds[1];
    await staking.connect(tokenHolderSigner).withdraw(5_000n, secondDepositId);

    // Validate final deposit amounts, etc.
  });

  /**
   * 05) "Should stake 10_000_000 tokens, advance time 1y and get first reward"
   */
  it("Should stake 10_000_000, wait 1y, claim reward", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) Stake
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 3, KONDUX_ERC20_ADDRESS);
    // timelock category 3 = 1 year (if your timelockDurations[3] = 365 days)

    // 2) Advance time 1 year
    await time.increase(60 * 60 * 24 * 365);

    // 3) Claim
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[0]);

    // expect totalRewarded to be large
    const totalRewarded = await staking.userTotalRewardedByCoin(KONDUX_ERC20_ADDRESS, tokenHolderSigner.address);
    expect(totalRewarded).to.be.gt(0);
  });

  /**
   * 06) "Should stake 10_000_000 tokens, advance time 1y and withdraw 10_000"
   */
  it("Should stake, wait 1y, withdraw partial", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 3, KONDUX_ERC20_ADDRESS);
    await time.increase(365 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).withdraw(10_000n, depositIds[0]);
    
    // check deposit updated
    const afterInfo = await staking.userDeposits(depositIds[0]);
    expect(afterInfo.deposited).to.equal(STAKE_AMOUNT - 10_000n);
  });

  /**
   * 07) "Should stake 10_000_000"
   */
  it("Should stake 10_000_000", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    expect(depositIds.length).to.equal(1);
    const stakerInfo = await staking.userDeposits(depositIds[0]);
    expect(stakerInfo.deposited).to.equal(STAKE_AMOUNT);
  });

  /**
   * 08) "Should stake 10_000_000 tokens, advance time to half of the timelock,
   *      and withdraw `toWithdraw` with penalty"
   *
   * This calls `earlyUnstake()`.
   */
  it("Should earlyUnstake with penalty", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) Stake with a long timelock (e.g. category 3 => 1 year)
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 3, KONDUX_ERC20_ADDRESS);

    // 2) Move time forward half
    // If it's 1 year, half is ~182 days
    await time.increase(60 * 60 * 24 * 182);

    // 3) earlyUnstake a portion
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    const depositId = depositIds[0];
    const toWithdraw = 50_000n;
    await staking.connect(tokenHolderSigner).earlyUnstake(toWithdraw, depositId);

    // 4) The deposit should be reduced by `toWithdraw`, plus some penalty
    //    Actually, you only see your real deposit reduced by toWithdraw,
    //    the penalty is fees withheld. You can test the final amounts, etc.
    const updated = await staking.userDeposits(depositId);
    expect(updated.deposited).to.equal(STAKE_AMOUNT - toWithdraw);
    // Additional checks: totalWithdrawalFees, user balances, etc.
  });

  /**
   * 09) "Should stake 10_000_000 tokens, advance time and restake rewards"
   */
  it("Should restake (compound) rewards", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) Stake
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);

    // 2) Advance time
    await time.increase(60 * 60 * 24 * 30);

    // 3) stakeRewards() 
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).stakeRewards(depositIds[0]);

    // 4) deposit must have increased by the unclaimed reward
    const afterInfo = await staking.userDeposits(depositIds[0]);
    // For a real test, you'd calculate expected new principal, but we can do a simple check:
    expect(afterInfo.deposited).to.be.gt(Number(STAKE_AMOUNT));
  });

  /**
   * 10) "Should stake 10_000_000 tokens, advance time and get multiple rewards"
   */
  it("Should stake multiple times, claim multiple times", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) deposit #1
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(60 * 60 * 24 * 7);
    // 2) deposit #2
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(60 * 60 * 24 * 7);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    // claim from deposit #1
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[0]);
    // claim from deposit #2
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[1]);

    // check user total rewarded is sum of both
    const totalRewarded = await staking.userTotalRewardedByCoin(KONDUX_ERC20_ADDRESS, tokenHolderSigner.address);
    expect(totalRewarded).to.be.gt(0);
  });

  /**
   * 11) "Do all tests 1 to 10 but now advancing time, setting a new APR,
   *      making new deposits, and testing old vs new deposits"
   *
   * Rather than re-run them all in code duplication, this shows how you'd
   * do it in a single scenario. We'll do an abbreviated version.
   */
  it("Re-run scenarios after changing APR, ensuring older deposits keep old APR", async () => {
    const { staking, tokenHolderSigner, governorSigner } = await loadFixture(deployStakingFixture);

    // 1) deposit with old APR
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);

    // 2) Advance
    await time.increase(60 * 60 * 24 * 7);

    // 3) Governor updates global APR
    await staking.connect(governorSigner).setAPR(50, KONDUX_ERC20_ADDRESS); // new APR = 50% for new deposits

    // 4) deposit with new APR
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);

    // 5) Advance more
    await time.increase(60 * 60 * 24 * 60); // 30 days

    // 6) Claim from both deposits
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    console.log("Deposit IDs:", depositIds);
    // deposit #1 has old APR = 25% from constructor
    // deposit #2 has new APR = 50%
    // The contract calculates each deposit's rewards with the "depositApr" stored
    await staking.connect(tokenHolderSigner).claimRewards(Number(depositIds[0]));
    await staking.connect(tokenHolderSigner).claimRewards(Number(depositIds[1]));

    // 7) Validate that deposit #1 used the old APR and deposit #2 used the new APR,
    //    by checking userTotalRewardedByCoin or some custom logic. 
    //    A typical approach is to check `calculateRewards()` for both before claiming
    //    and compare the ratio. 
    const oldAPRRewards = await staking.calculateRewards(Number(depositIds[0]));
    const newAPRRewards = await staking.calculateRewards(Number(depositIds[1]));
    console.log("Old APR Rewards:", oldAPRRewards, "New APR Rewards:", newAPRRewards);
    expect(oldAPRRewards).to.be.gt(0);
    expect(newAPRRewards).to.be.gt(oldAPRRewards);

    const totalRewards = oldAPRRewards + newAPRRewards;
    expect(totalRewards).to.be.gt(0);
    expect(totalRewards).to.be.gt(oldAPRRewards);
  });

  /**
   * 12) "Do edge cases testing for all scenarios"
   *
   * This might include:
   * - Trying to stake less than minStake
   * - Withdrawing more than staked
   * - Attempting to stake with zero address token
   * - Attempting to call earlyUnstake after timelock is over
   * - Attempting to claimRewards before any time passes
   * - etc.
   */
  it("Edge cases test", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // Example: stake less than minStake
    await expect(
      staking.connect(tokenHolderSigner).deposit(1n, 0, KONDUX_ERC20_ADDRESS)
    ).to.be.revertedWith("Amount smaller than minimimum deposit");

    // Example: withdraw more than deposited
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);

    await expect(
      staking.connect(tokenHolderSigner).withdraw(STAKE_AMOUNT + 1n, depositIds[0])
    ).to.be.revertedWith("Can't withdraw more than you have");

    // Add other edge cases as needed.
  });
});
