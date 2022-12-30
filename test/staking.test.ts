import { utils, BigNumber } from 'ethers';
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
} from "../types";
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("Staking minting", async function () {
    let authority: Authority;
    let treasury: Treasury;
    let staking: Staking;
    let kondux: KonduxERC20;
    let founders: KonduxERC721Founders;
    let knft: KonduxERC721kNFT;
    
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
            knft.address
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
    });

    it("Should stake 10_000_000 tokens, advance time 1h and get first reward", async function () {
        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);

        const mint = await kondux.connect(staker).faucet();
        await mint.wait();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));

        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");

        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(29));
        await approve.wait();

        const stake = await staking.connect(staker).deposit(10_000_000);
        await stake.wait();

        const depositInfo = await staking.connect(staker).getDepositInfo(stakerAddress);
        expect(depositInfo._stake).to.equal(10_000_000);

        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");


        expect(await staking.connect(staker).compoundRewardsTimer(stakerAddress)).to.equal(60 * 60 * 24); // 60 * 60 seconds
        expect(await staking.connect(staker).calculateRewards(stakerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        
        expect(await staking.connect(staker).compoundRewardsTimer(stakerAddress)).to.equal(0); // 0 rewards
        expect(await staking.connect(staker).calculateRewards(stakerAddress)).to.equal(6840); // 1 reward per hour 
        
        expect(staking.connect(staker).claimRewards()).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const claimRewards = await staking.connect(staker).claimRewards();
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        expect(claimEvent?.args?.amount).to.equal(9); // 1 reward per hour

        console.log("Account balance 7:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect((await kondux.connect(staker).balanceOf(stakerAddress)).mod(1000)).to.equal(9); // 1 reward (285) per hour


    });

    it("Should stake 10_000_000 tokens, advance time 1h and withdraw 10_000", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, 100_000_000_000_000);
        await approve.wait();

        const stake = await staking.deposit(10_000_000);
        await stake.wait();

        const depositInfo = await staking.getDepositInfo(ownerAddress);
        expect(depositInfo._stake).to.equal(10_000_000);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(285); // 1 reward per hour 
        
        expect(staking.withdraw(10_000)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(10_000); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(100000)).to.equal(10_000); // 1 reward (285) per hour

        expect(staking.withdraw(10_000_000_000)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(ownerAddress))._stake).to.equal(9_990_000); // 1 reward (285) per hour

    });

    it("Should stake 10_000_000 tokens, advance time 1h and withdrawAll", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, 100_000_000_000_000);
        await approve.wait();

        const stake = await staking.deposit(10_000_000);
        await stake.wait();

        const depositInfo = await staking.getDepositInfo(ownerAddress);
        expect(depositInfo._stake).to.equal(10_000_000);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(4); // 1 reward per hour 
        
        expect(staking.withdraw(10_000)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const withdraw = await staking.withdrawAll();
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(10_000_000 + 9); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(10_000_000)).to.equal(9); // 1 reward (285) per hour

        expect(staking.withdrawAll()).to.be.revertedWith("ou have no deposit");

        console.log("founder balance:", await founders.balanceOf(ownerAddress) + " founders");
        console.log("knft balance:", await knft.balanceOf(ownerAddress) + " knft");

    });

    it("Should stake 10_000_000_000 tokens, advance time 1h and get first reward", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, 100_000_000_000_000);
        await approve.wait();

        const stake = await staking.deposit(10_000_000_000);
        await stake.wait();

        const depositInfo = await staking.getDepositInfo(ownerAddress);
        expect(depositInfo._stake).to.equal(10_000_000_000);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeincrease);

        
        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(4); // 1 reward per hour 
        
        expect(staking.claimRewards()).to.be.revertedWith("Timelock not passed");

        await time.increase(timeincrease);

        const claimRewards = await staking.claimRewards();
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        expect(claimEvent?.args?.amount).to.equal(9); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(1000)).to.equal(9); // 1 reward (285) per hour


    });

    it("Should stake 10_000_000_000 tokens, advance time 1h and withdraw 10_000", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, 100_000_000_000_000);
        await approve.wait();

        const stake = await staking.deposit(10_000_000_000);
        await stake.wait();

        const depositInfo = await staking.getDepositInfo(ownerAddress);
        expect(depositInfo._stake).to.equal(10_000_000_000);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeincrease);

        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(4); // 1 reward per hour 
        
        expect(staking.withdraw(10_000)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeincrease);

        const withdraw = await staking.withdraw(10_000);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(10_000); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(100000)).to.equal(10_000); // 1 reward (285) per hour

        expect(staking.withdraw(10_000_000_000)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(ownerAddress))._stake).to.equal(9_990_000); // 1 reward (285) per hour

    });

    it("Should stake 10_000_000_000 tokens, advance time 1h and withdrawAll", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, 100_000_000_000_000);
        await approve.wait();

        const stake = await staking.deposit(10_000_000_000);
        await stake.wait();

        const depositInfo = await staking.getDepositInfo(ownerAddress);
        expect(depositInfo._stake).to.equal(10_000_000_000);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(60 * 60); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(timeincrease);

        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(4); // 1 reward per hour 
        
        expect(staking.withdraw(10_000)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeincrease);

        const withdraw = await staking.withdrawAll();
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(10_000_000 + 9); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(10_000_000)).to.equal(9); // 1 reward (285) per hour

        expect(staking.withdrawAll()).to.be.revertedWith("ou have no deposit");

        console.log("founder balance:", await founders.balanceOf(ownerAddress) + " founders");
        console.log("knft balance:", await knft.balanceOf(ownerAddress) + " knft");

    });


});
