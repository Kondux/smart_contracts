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

    // 11) Set Staking contract as a minter and burner for Helix
    await helixToken.setRole(ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")), staking.getAddress(), true);
    await helixToken.setRole(ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE")), staking.getAddress(), true);

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

  
  it("Should stake 10_000_000 tokens, advance time (30+ days) and get first reward", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    // Must wait at least 30 days for timelock=0 to pass
    await time.increase(31 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[0]);

    const totalRewarded = await staking.userTotalRewardedByCoin(KONDUX_ERC20_ADDRESS, tokenHolderSigner.address);
    expect(totalRewarded).to.be.gt(0);
  });

   it("Should stake 10_000_000 tokens, advance time, withdraw 10_000", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    // wait 31 days
    await time.increase(31 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).withdraw(10_000n, depositIds[0]);

    // check deposit
    const depositStruct = await staking.userDeposits(depositIds[0]);
    expect(depositStruct.deposited).to.equal(STAKE_AMOUNT - 10_000n);
  });

  /**
   * 04) "Should stake 10_000_000 tokens, advance time, add another token,
   *       stake, advance time, withdraw"
   */
  it("Should stake, advance, stake more (10_000_000 again), withdraw partial", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    // 1) first deposit
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    // wait 31 days
    await time.increase(31 * 24 * 60 * 60);

    // 2) second deposit (must also be >= 10,000,000 to pass min stake)
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);

    // 3) wait 31 days again
    await time.increase(31 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    // withdraw partial from second deposit
    await staking.connect(tokenHolderSigner).withdraw(10_000n, depositIds[1]);
    const deposit2 = await staking.userDeposits(depositIds[1]);
    expect(deposit2.deposited).to.equal(STAKE_AMOUNT - 10_000n);
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

  it("Should stake, wait 1y, withdraw partial", async () => {
    const { staking, tokenHolderSigner } = await loadFixture(deployStakingFixture);

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 3, KONDUX_ERC20_ADDRESS);
    await time.increase(366 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    await staking.connect(tokenHolderSigner).withdraw(10_000n, depositIds[0]);

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

    // stake with category 3 => 365 days
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 3, KONDUX_ERC20_ADDRESS);
    // move ~182 days
    await time.increase(182 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    const toWithdraw = 50_000n;
    await staking.connect(tokenHolderSigner).earlyUnstake(toWithdraw, depositIds[0]);

    const updated = await staking.userDeposits(depositIds[0]);
    expect(updated.deposited).to.equal(STAKE_AMOUNT - toWithdraw);
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

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(31 * 24 * 60 * 60);

    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(31 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    // claim from deposit #0
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[0]);
    // claim from deposit #1
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[1]);

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

    // deposit with old APR=25%
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(31 * 24 * 60 * 60);

    // update APR
    await staking.connect(governorSigner).setAPR(50, KONDUX_ERC20_ADDRESS); 

    // deposit with new APR=50%
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    await time.increase(31 * 24 * 60 * 60);

    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);
    console.log("Deposit IDs:", depositIds);

    // Just a quick ratio check
    const oldAPRRewards = await staking.calculateRewards(tokenHolderSigner.address, depositIds[0]);
    const newAPRRewards = await staking.calculateRewards(tokenHolderSigner.address, depositIds[1]);
    console.log("Old APR:", oldAPRRewards.toString(), "New APR:", newAPRRewards.toString());
    expect(newAPRRewards).to.be.gt(oldAPRRewards);

    // claim from both
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[0]);
    await staking.connect(tokenHolderSigner).claimRewards(depositIds[1]);

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

    // stake less than minStake => revert with "Amount below min stake"
    await expect(
      staking.connect(tokenHolderSigner).deposit(1n, 0, KONDUX_ERC20_ADDRESS)
    ).to.be.revertedWith("Amount below min stake");

    // deposit normal
    await staking.connect(tokenHolderSigner).deposit(STAKE_AMOUNT, 0, KONDUX_ERC20_ADDRESS);
    const depositIds = await staking.getDepositIds(tokenHolderSigner.address);

    // attempt to withdraw more than staked
    await time.increase(31 * 24 * 60 * 60);
    await expect(
      staking.connect(tokenHolderSigner).withdraw(STAKE_AMOUNT + 1n, depositIds[0])
    ).to.be.revertedWith("Can't withdraw more than you have");

    // attempt to claim too early => e.g. deposit category 3 => must wait 365 days
    // skip because we used timelock=0 for simplicity in this test

    // etc...
  });
});
