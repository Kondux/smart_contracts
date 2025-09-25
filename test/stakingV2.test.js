const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");
const { MaxUint256, keccak256, parseUnits, toUtf8Bytes } = require("ethers");

const MINTER_ROLE = keccak256(toUtf8Bytes("MINTER_ROLE"));
const BURNER_ROLE = keccak256(toUtf8Bytes("BURNER_ROLE"));

async function deployStakingV2Fixture() {
  const [owner, user, other] = await ethers.getSigners();
  const ownerAddress = await owner.getAddress();
  const userAddress = await user.getAddress();
  const otherAddress = await other.getAddress();

  const Authority = await ethers.getContractFactory("Authority", owner);
  const authority = await Authority.deploy(ownerAddress, ownerAddress, ownerAddress, ownerAddress);
  await authority.waitForDeployment();
  const authorityAddress = await authority.getAddress();

  const Treasury = await ethers.getContractFactory("Treasury", owner);
  const treasury = await Treasury.deploy(authorityAddress);
  await treasury.waitForDeployment();
  const treasuryAddress = await treasury.getAddress();

  await (await authority.pushVault(treasuryAddress, true)).wait();

  const KNDX = await ethers.getContractFactory("KNDX", owner);
  const kondux = await KNDX.deploy();
  await kondux.waitForDeployment();
  const konduxAddress = await kondux.getAddress();
  await (await kondux.enableTrading()).wait();
  await (await kondux.faucet()).wait();

  const Helix = await ethers.getContractFactory("Helix", owner);
  const helix = await Helix.deploy("Helix", "HLX");
  await helix.waitForDeployment();
  const helixAddress = await helix.getAddress();

  const Founders = await ethers.getContractFactory("KonduxERC721Founders", owner);
  const founders = await Founders.deploy();
  await founders.waitForDeployment();
  const foundersAddress = await founders.getAddress();

  const KonduxNFT = await ethers.getContractFactory("KonduxERC721kNFT", owner);
  const knft = await KonduxNFT.deploy();
  await knft.waitForDeployment();
  const knftAddress = await knft.getAddress();

  const StakingV2 = await ethers.getContractFactory("StakingV2", owner);
  if (!authorityAddress || !konduxAddress || !treasuryAddress || !foundersAddress || !knftAddress || !helixAddress) {
    throw new Error(
      `invalid ctor args ${JSON.stringify({
        authorityAddress,
        konduxAddress,
        treasuryAddress,
        foundersAddress,
        knftAddress,
        helixAddress,
      })}`
    );
  }
  const staking = await StakingV2.deploy(
    authorityAddress,
    konduxAddress,
    treasuryAddress,
    foundersAddress,
    knftAddress,
    helixAddress
  );
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();

  await (await treasury.setPermission(2, konduxAddress, true)).wait();
  await (await treasury.setStakingContract(stakingAddress)).wait();
  await (await treasury.setPermission(1, stakingAddress, true)).wait();
  await (await treasury.setPermission(0, stakingAddress, true)).wait();
  await (await treasury.setPermission(0, ownerAddress, true)).wait();

  await (await treasury.erc20ApprovalSetup(konduxAddress, MaxUint256)).wait();
  await (await kondux.approve(treasuryAddress, MaxUint256)).wait();
  await (await treasury.deposit(parseUnits("1000000", 18), konduxAddress)).wait();

  await (await helix.setAllowedContract(stakingAddress, true)).wait();
  await (await helix.setRole(MINTER_ROLE, stakingAddress, true)).wait();
  await (await helix.setRole(BURNER_ROLE, stakingAddress, true)).wait();

  const stakeAmount = parseUnits("1000", 18);
  await (await kondux.transfer(userAddress, stakeAmount * 10n)).wait();
  await (await kondux.transfer(otherAddress, stakeAmount * 10n)).wait();

  return {
    owner,
    user,
    other,
    ownerAddress,
    userAddress,
    otherAddress,
    staking,
    stakingAddress,
    kondux,
    konduxAddress,
    helix,
    stakeAmount,
  };
}

describe("StakingV2", function () {
  it("snapshots APR per deposit and protects existing stakes", async function () {
    const {
      owner,
      user,
      other,
      staking,
      stakingAddress,
      kondux,
      konduxAddress,
      stakeAmount,
    } = await loadFixture(deployStakingV2Fixture);

    const initialApr = await staking.getAPR(konduxAddress);

    await (await kondux.connect(user).approve(stakingAddress, stakeAmount)).wait();
    const depositIndex1 = await staking.connect(user).deposit.staticCall(stakeAmount, 0, konduxAddress);
    await (await staking.connect(user).deposit(stakeAmount, 0, konduxAddress)).wait();

    const snapshot1 = await staking.getDepositAprSnapshot(depositIndex1);
    expect(snapshot1[1]).to.equal(true);
    expect(snapshot1[0]).to.equal(initialApr);

    await (await staking.connect(owner).setAPR(50, konduxAddress)).wait();
    const updatedApr = await staking.getAPR(konduxAddress);
    expect(updatedApr).to.equal(50n);

    await (await kondux.connect(other).approve(stakingAddress, stakeAmount)).wait();
    const depositIndex2 = await staking
      .connect(other)
      .deposit.staticCall(stakeAmount, 0, konduxAddress);
    await (await staking.connect(other).deposit(stakeAmount, 0, konduxAddress)).wait();

    const snapshot2 = await staking.getDepositAprSnapshot(depositIndex2);
    expect(snapshot2[1]).to.equal(true);
    expect(snapshot2[0]).to.equal(updatedApr);

    await time.increase(60 * 60 * 24);

    const reward1 = await staking.calculateRewards(await user.getAddress(), depositIndex1);
    const reward2 = await staking.calculateRewards(await other.getAddress(), depositIndex2);

    expect(reward2).to.be.gt(reward1);
  });

  it("blocks restaking rewards after APR change", async function () {
    const {
      owner,
      user,
      staking,
      stakingAddress,
      kondux,
      konduxAddress,
      stakeAmount,
    } = await loadFixture(deployStakingV2Fixture);

    await (await kondux.connect(user).approve(stakingAddress, stakeAmount)).wait();
    const depositIndex = await staking
      .connect(user)
      .deposit.staticCall(stakeAmount, 0, konduxAddress);
    await (await staking.connect(user).deposit(stakeAmount, 0, konduxAddress)).wait();

    await time.increase(60 * 60 * 24);
    await (await staking.connect(user).stakeRewards(depositIndex)).wait();

    await (await staking.connect(owner).setAPR(75, konduxAddress)).wait();
    const currentApr = await staking.getAPR(konduxAddress);
    const snapshot = await staking.getDepositAprSnapshot(depositIndex);

    await time.increase(60 * 60 * 24);
    await expect(staking.connect(user).stakeRewards(depositIndex))
      .to.be.revertedWithCustomError(staking, "APRChangedForDeposit")
      .withArgs(depositIndex, snapshot[0], currentApr);
  });
});
