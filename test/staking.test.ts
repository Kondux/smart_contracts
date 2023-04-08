import { utils } from 'ethers';
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
    let kondux2: KonduxERC20;
    let founders: KonduxERC721Founders;
    let knft: KonduxERC721kNFT;
    let helix: Helix;
    
    const timeIncrease = 60 * 60 * 24; // 1 day
    beforeEach(async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();
        console.log("Owner address:", ownerAddress);
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

        kondux2 = await new KonduxERC20__factory(owner).deploy();
        await kondux2.deployed();
        console.log("KNDX2 address:", kondux2.address);

        helix = await new Helix__factory(owner).deploy("Helix", "HLX");
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
        
        const setupApproval = await treasury.erc20ApprovalSetup(kondux.address, ethers.BigNumber.from(10).pow(38));
        await setupApproval.wait();

        const approve = await kondux.approve(treasury.address, ethers.BigNumber.from(10).pow(38));
        await approve.wait();
        console.log("Account balance 3:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const deposit = await treasury.deposit(ethers.BigNumber.from(10).pow(28), kondux.address);
        await deposit.wait();
        console.log("Account balance 4:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const whitelistStaking = await helix.setAllowedContract(staking.address, true); 
        await whitelistStaking.wait();
        console.log("Staking contract is whitelisted:", staking.address);

        const setHelixMinter = await helix.setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), staking.address, true);
        await setHelixMinter.wait();
        console.log("Staking contract is minter:", staking.address);

        const setHelixBurner = await helix.setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("BURNER_ROLE")), staking.address, true);
        await setHelixBurner.wait();
        console.log("Staking contract is burner:", staking.address);
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
        
        const stake = await staking.connect(staker).deposit(ethers.BigNumber.from(10).pow(18), 4, kondux.address);
        const stakeReceipt = await stake.wait();

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(stakerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.connect(staker).getDepositInfo(stakeId);
        console.log("Stake info:", depositInfo);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18)); 

        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");


        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(60 * 60 * 24); // 60 * 60 seconds
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
        // rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 4, kondux.address);
        const stakeReceipt = await stake.wait();

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(stakeId);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18));

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer);
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(ethers.BigNumber.from("790020000000000")); // 1 reward per hour 
        
        expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(9900); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(100000)).to.equal(19800); // 1 reward (285) per hour

        expect(staking.withdraw(10_000_000_000, stakeId)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(stakeId))._stake).to.equal(ethers.BigNumber.from("999999999999980000")); // 1 reward (285) per hour

        // get user deposits ids
        const userDeposits = await staking.getDepositIds(ownerAddress);
        expect(userDeposits.length).to.equal(1);
        expect(userDeposits[0]).to.equal(stakeId);

    });

    it("Should stake 10_000_000 tokens, advance time 1h, add another token", async function () {
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 86400; // 60 * 60 * 24 
        // rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 4, kondux.address);
        const stakeReceipt = await stake.wait();

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(0);
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(0);

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        expect(staking.withdraw(10_000, stakeId)).to.be.reverted;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(stakeId);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18));

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer);
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(ethers.BigNumber.from("790020000000000")); // 1 reward per hour 
        
        // expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.amount).to.equal(9900); // 1 reward per hour
        // check totalstaked
        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(0);
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(0);

        // Add another token and stake it
        const newToken = await staking.addNewStakingToken(kondux2.address, 285, 60 * 60 * 24, 100_000, 10_000_000, 11_000_000, 10_000_000, 100_000, 10_000_000, 10_000, 10_000_000);
        const newTokenReceipt = await newToken.wait();
        const newTokenEvent = newTokenReceipt.events?.find((e) => e.event === "NewAuthorizedERC20");
        const newTokenId = newTokenEvent?.args?.token;
        expect(newTokenId).to.equal(kondux2.address);

        const approve2 = await kondux2.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve2.wait();

        const setupApproval = await treasury.erc20ApprovalSetup(kondux2.address, ethers.BigNumber.from(10).pow(38));
        await setupApproval.wait();

        console.log("Account balance 7:", await kondux2.balanceOf(ownerAddress) + " KNDX2");

        const stake2 = await staking.deposit(ethers.BigNumber.from(10).pow(18), 4, kondux2.address);
        const stakeReceipt2 = await stake2.wait();

        const stakeEvent2 = stakeReceipt2.events?.filter((e) => e.event === "Stake")[0];
        const stakeId2 = stakeEvent2?.args?.id;

        console.log("Stake id:", stakeId2);

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        
        expect(staking.withdraw(10_000, stakeId2)).to.be.reverted;

        const depositInfo2 = await staking.getDepositInfo(stakeId2);
        expect(depositInfo2._stake).to.equal(ethers.BigNumber.from(10).pow(18));

        console.log("Account balance 8:", await kondux2.balanceOf(ownerAddress) + " KNDX2");

        expect(await staking.compoundRewardsTimer(stakeId2)).to.equal(rewardTimer);
        expect(await staking.calculateRewards(ownerAddress, stakeId2)).to.equal(0); // 0 rewards
        
        await time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId2)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId2)).to.equal(ethers.BigNumber.from("759924000000000")); // 1 reward per hour 
        

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        await time.increase(timeIncrease);
        
        const withdraw2 = await staking.withdraw(10_000, stakeId2);
        const withdrawReceipt2 = await withdraw2.wait();
        const withdrawEvent2 = withdrawReceipt2.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent2?.args?.amount).to.equal(9900); // 1 reward per hour

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        
        

    });

});
