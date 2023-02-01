import { utils, BigNumber } from 'ethers';
import { keccak256 } from 'ethers/lib/utils';
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { mine, time } = require("@nomicfoundation/hardhat-network-helpers");

import {
    Authority,
    Authority__factory,
    Staking,
    Staking__factory,
    Treasury,
    Treasury__factory,
    KonduxERC20,
    KonduxERC20__factory,
    KonduxERC721Founders,
    KonduxERC721Founders__factory,
    KonduxERC721kNFT,
    KonduxERC721kNFT__factory,
    Helix,
    Helix__factory,
} from "../types";
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("Staking minting", async function () {
    let authority: Authority;
    let treasury: Treasury;
    let staking: Staking;
    let kondux: KonduxERC20;
    let founders: KonduxERC721Founders;
    let knft: KonduxERC721kNFT;
    let helix: Helix;
    
    const timeIncrease = 60 * 60 * 24; // 1 day
    beforeEach(async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();
        authority = await new Authority__factory(owner).deploy(
            ownerAddress,
            ownerAddress,
            ownerAddress,
            ownerAddress
        );

        treasury = await new Treasury__factory(owner).deploy(
            authority.address
        );
        await treasury.deployed();
        console.log("Treasury address:", treasury.address);

        const pushVault = await authority.pushVault(treasury.address, true);
        await pushVault.wait();

        kondux = await new KonduxERC20__factory(owner).deploy();
        await kondux.deployed();
        console.log("KNDX address:", kondux.address);

        helix = await new Helix__factory(owner).deploy("Helix", "HLX", authority.address);
        await helix.deployed();
        console.log("Helix address:", helix.address);

        founders = await new KonduxERC721Founders__factory(owner).deploy();
        await founders.deployed();
        console.log("Founders address:", founders.address);

        knft = await new KonduxERC721kNFT__factory(owner).deploy();
        await knft.deployed();
        console.log("kNFT address:", knft.address);

        staking = await new Staking__factory(owner).deploy(
            authority.address,
            kondux.address,
            treasury.address,
            founders.address,
            knft.address,
            helix.address
        );
        await staking.deployed();
        console.log("Staking address:", staking.address);

        const setupApproval = await treasury.erc20ApprovalSetup(kondux.address, ethers.BigNumber.from(10).pow(38));
        await setupApproval.wait();

        const setKNDX = await treasury.setPermission(2, kondux.address, true); 
        await setKNDX.wait();

        const setStaking = await treasury.setStakingContract(staking.address);
        await setStaking.wait();

        const setSpender = await treasury.setPermission(1, staking.address, true);
        await setSpender.wait();

        const setDepositor = await treasury.setPermission(0, staking.address, true);
        await setDepositor.wait();

        const setInitialDepositor = await treasury.setPermission(0, ownerAddress, true);
        await setInitialDepositor.wait();
        console.log("Account balance 1:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(treasury.address, ethers.BigNumber.from(10).pow(38));
        await approve.wait();
        console.log("Account balance 3:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const deposit = await treasury.deposit(ethers.BigNumber.from(10).pow(28), kondux.address);
        await deposit.wait();
        console.log("Account balance 4:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const setMinter = await authority.pushRole(staking.address, utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE")));
        await setMinter.wait();
        console.log("Staking contract is minter:", staking.address);
    });

    it("Should stake 10_000_000 tokens, advance time 1h and get first reward", async function () {
        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);

        const mint = await kondux.connect(staker).faucet();
        await mint.wait();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));

        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");

        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        // const approve2 = await kondux.connect(staker).approve(treasury.address, ethers.BigNumber.from(10).pow(28));
        // await approve2.wait();

        const stake = await staking.connect(staker).deposit(ethers.BigNumber.from(10).pow(18), 4);
        const stakeReceipt = await stake.wait();

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.connect(staker).getDepositInfo(stakerAddress, stakeId);
        console.log("Stake info:", depositInfo);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18)); 

        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");


        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        
        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(ethers.BigNumber.from(10).pow(11).mul(6840)); // 1 reward per hour 
        
        expect(staking.connect(staker).claimRewards(stakeId)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const claimRewards = await staking.connect(staker).claimRewards(stakeId);
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        expect(claimEvent?.args?.amount).to.equal(7916666666); // 1 reward per hour

        console.log("Account balance 7:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect((await kondux.connect(staker).balanceOf(stakerAddress)).mod(1000)).to.equal(332); // 1 reward (285) per hour


    });

    it("Should stake 10_000_000 tokens, advance time 1h and withdraw 10_000", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 86400; // 60 * 60 * 24 
        rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 4);
        const stakeReceipt = await stake.wait();

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(ownerAddress, stakeId);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18));

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer);
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(ethers.BigNumber.from("759924000000000")); // 1 reward per hour 
        
        expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(9900); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(100000)).to.equal(19800); // 1 reward (285) per hour

        expect(staking.withdraw(10_000_000_000, stakeId)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(ownerAddress, stakeId))._stake).to.equal(ethers.BigNumber.from("999999999999980000")); // 1 reward (285) per hour

    });

    it("Should stake 10_000_000 tokens, advance time 1h and withdrawAll", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        const rewardTimer = 3600; // 60 * 60 * 24 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(14), 4);
        const stakeReceipt = await stake.wait();

        const stake2 = await staking.deposit(ethers.BigNumber.from(10).pow(14), 4);
        const stake2Receipt = await stake2.wait();

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(ownerAddress, stakeId);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(14));

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer - 1);
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(879540); // 0 rewards
        
        await time.increase(timeIncrease);

        console.log("time latest:", await time.latest());
        console.log("time of last update:", await staking.getTimeOfLastUpdate(stakeId));
        console.log("staked amount:", await staking.getStakedAmount(stakeId));
        console.log("rewards per hour:", await staking.getRewardsPerHour());

        let _reward = (((((await time.latest() - Number(await staking.getTimeOfLastUpdate(stakeId))) * 
        Number(await staking.getStakedAmount(stakeId))) * Number(await staking.getRewardsPerHour())) / 3600) / 10_000_000); // blocks * staked * rewards/hour / 1h / 10^7

        if (Number(await founders.balanceOf(ownerAddress)) > 0) {
            _reward = (_reward * Number(await staking.getFoundersRewardBoost())) / Number(await staking.getFoundersRewardBoostDenominator());
        }

        let knftBalance = Number(await knft.balanceOf(ownerAddress));
        if (knftBalance > 5) {
            knftBalance = 5;
        }

        console.log("knftBalance:", knftBalance);
        console.log("getkNFTRewardBoost:", Number(await staking.getkNFTRewardBoost()));
        console.log("getKnftRewardBoostDenominator:", Number(await staking.getKnftRewardBoostDenominator()));
        console.log("reward:", _reward);

        // _reward = (_reward * (Number(await staking.getkNFTRewardBoost()) * knftBalance)) / Number(await staking.getKnftRewardBoostDenominator()); // -7524000000000000000000

        let multiplier = (Number(await staking.getKnftRewardBoostDenominator()) + (knftBalance * Number(await staking.getkNFTRewardBoost()))) / Number(await staking.getKnftRewardBoostDenominator());

        console.log("multiplier:", multiplier); 

        _reward = _reward * multiplier;

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(_reward.toFixed(0) - 2); // 1 reward per hour 
        
        // expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);
        
        multiplier = (Number(await staking.getKnftRewardBoostDenominator()) + (knftBalance * Number(await staking.getkNFTRewardBoost()))) / Number(await staking.getKnftRewardBoostDenominator());
        const amount = _reward * multiplier + Number((await staking.getDepositInfo(ownerAddress, stakeId))._stake);
        
        const _liquid = amount * (Number(await staking.getWithdrawalFeeDivisor()) - Number(await staking.getWithdrawalFee())) / Number(await staking.getWithdrawalFeeDivisor()); 

        const withdraw = await staking.withdrawAll();
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "WithdrawAll");
        

        // console.log("withdrawEvent:", withdrawEvent);
        expect(withdrawEvent?.args?.amount).to.equal(198300932516235); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress))).to.equal(ethers.BigNumber.from( "89999999999999998300932516235")); // 1 reward (285) per hour

        expect(staking.withdrawAll()).to.be.revertedWith("You have no deposit");

        console.log("founder balance:", await founders.balanceOf(ownerAddress) + " founders");
        console.log("knft balance:", await knft.balanceOf(ownerAddress) + " knft");

    });

});
