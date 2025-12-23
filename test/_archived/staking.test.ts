import { BigNumber, utils } from 'ethers';
const { expect } = require("chai");
const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

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
    Kondux,
    Kondux__factory,
    Helix,
    Helix__factory,
    KNDX,
    KNDX__factory,
} from "../types";
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("Staking minting", async function () {
    let authority: Authority;
    let treasury: Treasury;
    let staking: Staking;
    let kondux: KNDX;
    let kondux2: KNDX;
    let founders: KonduxERC721Founders;
    let knft: Kondux;
    let helix: Helix;
    let snapshot: any;

    let timeIncrease = 60 * 60 * 24; // 1 day
    timeIncrease = 60 * 60 * 24 * 7; // 1 week
    timeIncrease = 60 * 60 * 24 * 7 * 4; // 1 month
    // timeIncrease = 60 * 60 * 24 * 7 * 4 * 3; // 3 months
    // timeIncrease = 60 * 60 * 24 * 7 * 4 * 3 * 6; // 6 months
    // timeIncrease = 60 * 60 * 24 * 7 * 4 * 3 * 6 * 12; // 1 year = 31536000
    // timeIncrease = 31556926; // 1 year = 31536000

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

        kondux = await new KNDX__factory(owner).deploy();
        await kondux.deployed();
        const konduxEnableTrading = await kondux.enableTrading();
        await konduxEnableTrading.wait();
        const konduxFaucet = await kondux.faucet();
        await konduxFaucet.wait();
        console.log("KNDX address:", kondux.address);

        kondux2 = await new KNDX__factory(owner).deploy();
        await kondux2.deployed();
        const kondux2EnableTrading = await kondux2.enableTrading();
        await kondux2EnableTrading.wait();
        const kondux2Faucet = await kondux2.faucet();
        await kondux2Faucet.wait();
        console.log("KNDX2 address:", kondux2.address);

        helix = await new Helix__factory(owner).deploy("Helix", "HLX");
        await helix.deployed();
        console.log("Helix address:", helix.address);

        founders = await new KonduxERC721Founders__factory(owner).deploy();
        await founders.deployed();
        console.log("Founders address:", founders.address);

        knft = await new Kondux__factory(owner).deploy("Kondux NFT", "KNFT");
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
        console.log("Account balance 2:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(treasury.address, ethers.BigNumber.from(10).pow(38));
        await approve.wait();
        console.log("Account balance 3:", await kondux.balanceOf(ownerAddress) + " KNDX");
        console.log("Approval:", await kondux.allowance(ownerAddress, treasury.address) + " KNDX");

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

        console.log("Owner knft balance:", await knft.balanceOf(ownerAddress));
        const mintKnft = await knft.connect(owner).safeMint(ownerAddress, 0);
        const mintKnftReceipt = await mintKnft.wait();        
        const mintedTokenId = mintKnftReceipt.events?.filter((x) => x.event == "Transfer")[0].args?.tokenId;
        console.log("Minted token id:", mintedTokenId);
        console.log("Owner knft balance:", await knft.balanceOf(ownerAddress));
        console.log("Owner of id", await knft.ownerOf(mintedTokenId));

        const setGenVersion = await knft.writeGen(mintedTokenId, 1, 0, 1);
        await setGenVersion.wait();
        console.log("Gen version:", await knft.readGen(mintedTokenId, 0, 1));

        const setGenBoost = await knft.writeGen(mintedTokenId, 5, 1, 2);
        await setGenBoost.wait();
        console.log("Gen boost:", await knft.readGen(mintedTokenId, 1, 2));
            
        const dna = await knft.getDna(mintedTokenId);
        console.log("DNA:", dna.toHexString());

        const approveKndx = await treasury.setPermission(2, kondux.address, true);
        await approveKndx.wait();

        const approveOwnerAsSpender = await treasury.setPermission(1, ownerAddress, true);
        await approveOwnerAsSpender.wait();                    

        // take a snapshot of the current state of the blockchain
        snapshot = await helpers.takeSnapshot();
    });

    it("Should mint kNFTs with 5% boost and check if the boost modifies the calculateRewards(...) expected result", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60 * 24 * 30 + 60 * 60; // 1 month
    
        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        const stakeAmount = ethers.BigNumber.from(10).pow(18);
        
        const bonus = 5; // 5% boost

        expect(await knft.balanceOf(stakerAddress)).to.equal(0);            
    
        const mintKnft = await knft.connect(owner).safeMint(stakerAddress, 0);
        const mintKnftReceipt = await mintKnft.wait();        
        const mintedTokenId = mintKnftReceipt.events?.filter((x) => x.event == "Transfer")[0].args?.tokenId;
        console.log("Minted token id:", mintedTokenId);
        console.log("Owner knft balance:", await knft.balanceOf(stakerAddress));
        console.log("Owner of id", await knft.ownerOf(mintedTokenId));

        const setGenVersion = await knft.connect(owner).writeGen(mintedTokenId, 1, 0, 1);
        await setGenVersion.wait();
        console.log("Gen version:", await knft.readGen(mintedTokenId, 0, 1));

        const setGenBoost = await knft.connect(owner).writeGen(mintedTokenId, bonus, 1, 2);
        await setGenBoost.wait();
        console.log("Gen boost:", await knft.readGen(mintedTokenId, 1, 2));
            
        const dna = await knft.getDna(mintedTokenId);
        console.log("DNA:", dna.toHexString());
    
        expect(await knft.balanceOf(stakerAddress)).to.equal(1);
        const tokenId = await knft.tokenOfOwnerByIndex(stakerAddress, 0);
        const dnaBoost = await knft.readGen(tokenId, 1, 2);
        expect(dnaBoost).to.equal(bonus);
        
        await console.log("Rewarded token 1:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 1:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        
        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);
        
        const mint = await kondux.connect(staker).faucet();
        await mint.wait();
        
        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));
        
        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");
        
        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();
        
        expect(await helix.balanceOf(stakerAddress)).to.equal(0);
        
        const stake = await staking.connect(staker).deposit(stakeAmount, 4, kondux.address);
        const stakeReceipt = await stake.wait();
        
        console.log("Rewarded token 2:", await staking.getTotalRewards(kondux.address) + " KNDX");
        console.log("Rewarded  user 2:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");
        
        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(stakerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        
        const helixRatio = await staking.getRatioERC20(kondux.address);
        expect(await helix.balanceOf(stakerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9));
        console.log("Helix ratio:", helixRatio.toString());
        console.log("Helix balance:", await helix.balanceOf(stakerAddress) + " HELIX");
        console.log("Stake amount:", stakeAmount.toString() + " KNDX");
        console.log("Stake amount in Helix:", stakeAmount.mul(helixRatio).mul(1e9).toString() + " HELIX");
        
        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;
        
        console.log("Stake id:", stakeId);
        
        const depositInfo = await staking.connect(staker).getDepositInfo(stakeId);
        console.log("Stake info:", depositInfo);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18)); 
        
        await console.log("Rewarded token 3:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 3:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        
        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");
        
        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.be.closeTo(60 * 60 * 24, 10); // 60 * 60 seconds
        // expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0); // 0 rewards
        
        console.log("%%%% TIME 2: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS before:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));
        await helpers.time.increase(timeIncrease);
        console.log("%%%% TIME 3: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS after:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));
        
        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(0); // 23h left
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour 
        
        // Replace the original rewards calculation with the boosted rewards calculation
        const originalReward = await staking.connect(staker).calculateRewards(stakerAddress, stakeId);
        
        // const boostedReward = originalReward.mul(100 + bonus).div(100);

        // console.log("Original reward:", originalReward.toString());
        // console.log("Boosted reward:", boostedReward.toString());
    
        // expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(boostedReward, ethers.BigNumber.from(10).pow(11));

        const bonuses = [1, 10, 25, 50];
        const totalBoost = bonuses.reduce((a, b) => a + b, 0) + bonus; // 5 is the initial bonus

        for (const bonus of bonuses) {
            const mintKnft = await knft.connect(owner).safeMint(stakerAddress, 0);
            const mintKnftReceipt = await mintKnft.wait();        
            const mintedTokenId = mintKnftReceipt.events?.filter((x) => x.event == "Transfer")[0].args?.tokenId;
            console.log("Minted token id:", mintedTokenId);
            console.log("Owner knft balance:", await knft.balanceOf(stakerAddress));
            console.log("Owner of id", await knft.ownerOf(mintedTokenId));

            const setGenVersion = await knft.connect(owner).writeGen(mintedTokenId, 1, 0, 1);
            await setGenVersion.wait();
            console.log("Gen version:", await knft.readGen(mintedTokenId, 0, 1));

            const setGenBoost = await knft.connect(owner).writeGen(mintedTokenId, bonus, 1, 2);
            await setGenBoost.wait();
            console.log("Gen boost:", await knft.readGen(mintedTokenId, 1, 2));
                
            const dna = await knft.getDna(mintedTokenId);
            console.log("DNA:", dna.toHexString());
    
            const tokenId = await knft.tokenOfOwnerByIndex(stakerAddress, (await knft.balanceOf(stakerAddress)).toNumber() - 1);
            const dnaBoost = await knft.readGen(tokenId, 1, 2);
            expect(dnaBoost).to.equal(bonus); 
        }

        expect(await knft.balanceOf(stakerAddress)).to.equal(5);

        const boostedReward2 = originalReward.mul(100 + totalBoost).div(100);

        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour

        // expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(boostedReward2, ethers.BigNumber.from(10).pow(11));

    });
    
    it("Should stake 10_000_000 tokens, advance time 1h and get first reward", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60; // 1 hour

        console.log("%%%% TIME 1: ", await helpers.time.latest());

        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        await console.log("Rewarded token 1:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 1:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");

        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);

        const mint = await kondux.connect(staker).faucet();
        await mint.wait();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));

        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");

        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();
        
        const stake = await staking.connect(staker).deposit(ethers.BigNumber.from(10).pow(18), 4, kondux.address);
        const stakeReceipt = await stake.wait();

        await console.log("Rewarded token 2:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 2:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(stakerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.connect(staker).getDepositInfo(stakeId);
        console.log("Stake info:", depositInfo);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18)); 

        await console.log("Rewarded token 3:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 3:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");

        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(60 * 60 * 24); // 60 * 60 seconds
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0); // 0 rewards
        
        console.log("%%%% TIME 2: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS before:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));
        await helpers.time.increase(timeIncrease);
        console.log("%%%% TIME 3: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS after:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));

        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.be.closeTo(60 * 60 * 23, 10); // 23h left
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour 

        await console.log("Rewarded token 4:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 4:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        
        //expect(staking.connect(staker).claimRewards(stakeId)).to.be.revertedWith("Timelock not passed");
        console.log("%%%% TIME 2: ", await helpers.time.latest());
        await helpers.time.increase(timeIncrease);
        console.log("%%%% TIME 3: ", await helpers.time.latest());

        await console.log("Rewarded token 5:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 5:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        await console.log("Calculate rewrd:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId) + " KNDX");


        const claimRewards = await staking.connect(staker).claimRewards(stakeId);
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        // expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0);
        // expect((await staking.connect(staker).getDepositInfo(stakeId))._unclaimedRewards).to.equal(0);

        expect(claimEvent?.args?.netRewards).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(2), ethers.BigNumber.from(10).pow(13).mul(2)); // 1 reward per hour

        await console.log("Rewarded token 6:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 6:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");

        expect(await staking.connect(staker).getUserTotalRewardsByCoin(stakerAddress, kondux.address)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(2), ethers.BigNumber.from(10).pow(13).mul(2));
        expect(await staking.connect(staker).getTotalRewards(kondux.address)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(2), ethers.BigNumber.from(10).pow(13).mul(2));

        console.log("Account balance 7:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect((await kondux.connect(staker).balanceOf(stakerAddress))).to.be.closeTo(ethers.BigNumber.from(10).pow(29).sub(ethers.BigNumber.from(10).pow(18)), ethers.BigNumber.from(10).pow(17));
        
        // expect to have 0 rewards to be claimed and pending
        expect((await staking.connect(staker).getDepositInfo(stakeId))._stake).to.equal(ethers.BigNumber.from(10).pow(18));
        
    });

    it("Should stake 10_000_000 tokens, advance time 1 day and withdraw 10_000", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60; // 1 hour
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 60 * 60 * 24;  //86400
        // rewardTimer = 3600; // 60 * 60 

        const stakeAmount = ethers.BigNumber.from(10).pow(18);
        const withdrawAmount = ethers.BigNumber.from(10).pow(7);
        const stakerInitialBalance = await kondux.balanceOf(ownerAddress);

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        expect(await helix.balanceOf(ownerAddress)).to.equal(0);

        const stake = await staking.deposit(stakeAmount, 3, kondux.address);
        const stakeReceipt = await stake.wait();

        expect(await staking.getTotalStaked(kondux.address)).to.equal(stakeAmount); 
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(stakeAmount);

        const helixRatio = await staking.getRatioERC20(kondux.address);
        expect(await helix.balanceOf(ownerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(stakeId);
        expect(depositInfo._stake).to.equal(stakeAmount);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        // expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer); DEPRECATED
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await helpers.time.increase(timeIncrease);

        // expect(await staking.compoundRewardsTimer(stakeId)).to.equal(60 * 60 * 23); // rewards DEPRECATED
        console.log("REWARDS:", await staking.calculateRewards(ownerAddress, stakeId));
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.be.closeTo(stakeAmount.div(4).div(12).div(30).div(24), ethers.BigNumber.from(10).pow(13)); // 1 reward per hour 
        
        // expect(staking.withdraw(withdrawAmount, stakeId)).to.be.revertedWith("Timelock not passed");

        await helpers.time.increase(timeIncrease);

        const helixBalance = await helix.balanceOf(ownerAddress);
        // expect(helixBalance).to.equal();

        expect(await helix.balanceOf(ownerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9));

        const withdraw = await staking.withdraw(withdrawAmount, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.liquidAmount).to.equal(withdrawAmount.mul(99).div(100)); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress))).to.equal(stakerInitialBalance.sub(stakeAmount).add(withdrawAmount.mul(99).div(100))); // 1 reward (285) per hour

        expect(await helix.balanceOf(ownerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9).sub(withdrawAmount.mul(helixRatio).mul(1e9)));

        //expect(staking.withdraw(10_000_000_000, stakeId)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(stakeId))._stake).to.equal(stakeAmount.sub(withdrawAmount)); // 1 reward (285) per hour

        // get user deposits ids
        const userDeposits = await staking.getDepositIds(ownerAddress);
        expect(userDeposits.length).to.equal(1);
        expect(userDeposits[0]).to.equal(stakeId);

    });

    it("Should stake 10_000_000 tokens, advance time 1h, add another token", async function () {
        snapshot.restore();
        //timeIncrease = 60 * 60; // 1 hour
        timeIncrease = 60 * 60 * 24 * 365; // 1 year 
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 86400; // 60 * 60 * 24 
        // rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 3, kondux.address);
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
        
        await helpers.time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(13).mul(2)); // 1 reward per hour
        
        // expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await helpers.time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.liquidAmount).to.equal(9900); // 1 reward per hour
        // check totalstaked
        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(0);
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(0);

        // Add another token and stake it
        const newToken = await staking.addNewStakingToken(kondux2.address, 25, 60 * 60 * 24, 100, 1_000, 500, 10_000, 10_000_000);
        const newTokenReceipt = await newToken.wait();
        const newTokenEvent = newTokenReceipt.events?.find((e) => e.event === "NewAuthorizedERC20");
        const newTokenId = newTokenEvent?.args?.token;
        expect(newTokenId).to.equal(kondux2.address);

        const approve2 = await kondux2.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve2.wait();

        const setupApproval = await treasury.erc20ApprovalSetup(kondux2.address, ethers.BigNumber.from(10).pow(38));
        await setupApproval.wait();

        console.log("Account balance 7:", await kondux2.balanceOf(ownerAddress) + " KNDX2");

        const stake2 = await staking.deposit(ethers.BigNumber.from(10).pow(18), 3, kondux2.address);
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
        
        await helpers.time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId2)).to.equal(60 * 60 * 23); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId2)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24), ethers.BigNumber.from(10).pow(13).mul(2)); // 1 reward per hour

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        await helpers.time.increase(timeIncrease);
        
        const withdraw2 = await staking.withdraw(10_000, stakeId2);
        const withdrawReceipt2 = await withdraw2.wait();
        const withdrawEvent2 = withdrawReceipt2.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent2?.args?.liquidAmount).to.equal(9900); // 1 reward per hour

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));

    });

    /// 1 YEAR TESTS ///

    it("Should stake 10_000_000 tokens, advance time 1y and get first reward", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60 * 24 * 7 * 4;

        console.log("%%%% TIME 1: ", await helpers.time.latest());

        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        await console.log("Rewarded token 1:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 1:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");

        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);

        const mint = await kondux.connect(staker).faucet();
        await mint.wait();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));

        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");

        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();
        
        const stake = await staking.connect(staker).deposit(ethers.BigNumber.from(10).pow(18), 0, kondux.address);
        const stakeReceipt = await stake.wait();

        await console.log("Rewarded token 2:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 2:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(stakerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.connect(staker).getDepositInfo(stakeId);
        console.log("Stake info:", depositInfo);
        expect(depositInfo._stake).to.equal(ethers.BigNumber.from(10).pow(18)); 

        console.log("Rewarded token 3:", await staking.getTotalRewards(kondux.address) + " KNDX");
        console.log("Rewarded  user 3:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");

        console.log("Account balance 6:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.be.closeTo(60 * 60 * 24, 10); // 60 * 60 seconds
        // expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0); // 0 rewards
        
        console.log("%%%% TIME 2: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS before:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));
        await helpers.time.increase(timeIncrease);
        console.log("%%%% TIME 3: ", await helpers.time.latest());
        await console.log("CALCULATING REWARDS after:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId));

        expect(await staking.connect(staker).compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour 

        await console.log("Rewarded token 4:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 4:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        
        //expect(staking.connect(staker).claimRewards(stakeId)).to.be.revertedWith("Timelock not passed");
        console.log("%%%% TIME 2: ", await helpers.time.latest());
        await helpers.time.increase(timeIncrease);
        console.log("%%%% TIME 3: ", await helpers.time.latest());

        await console.log("Rewarded token 5:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 5:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");
        await console.log("Calculate rewrd:", await staking.connect(staker).calculateRewards(stakerAddress, stakeId) + " KNDX");


        const claimRewards = await staking.connect(staker).claimRewards(stakeId);
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        expect(claimEvent?.args?.netRewards).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).mul(2), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour

        await console.log("Rewarded token 6:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 6:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");

        expect(await staking.connect(staker).getUserTotalRewardsByCoin(stakerAddress, kondux.address)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).mul(2), ethers.BigNumber.from(10).pow(16));
        expect(await staking.connect(staker).getTotalRewards(kondux.address)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12).mul(2), ethers.BigNumber.from(10).pow(16));

        console.log("Account balance 7:", await kondux.connect(staker).balanceOf(stakerAddress) + " KNDX");

        expect((await kondux.connect(staker).balanceOf(stakerAddress))).to.be.closeTo(ethers.BigNumber.from(10).pow(29).sub(ethers.BigNumber.from(10).pow(18)), ethers.BigNumber.from(10).pow(17));
        
        // expect to have 0 rewards to be claimed and pending
        //expect(await staking.connect(staker).calculateRewards(stakerAddress, stakeId)).to.equal(0);
        expect((await staking.connect(staker).getDepositInfo(stakeId))._stake).to.equal(ethers.BigNumber.from(10).pow(18));
        // expect((await staking.connect(staker).getDepositInfo(stakeId))._unclaimedRewards).to.equal(0);
        
    });

    it("Should stake 10_000_000 tokens, advance time 1y and withdraw 10_000", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60 * 24 * 7 * 4;

        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 86400; // 60 * 60 * 24 
        // rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 0, kondux.address);
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
        
        await helpers.time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour 
        
        expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await helpers.time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.liquidAmount).to.equal(9900); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(100000)).to.equal(9900); // 1 reward (285) per hour

        expect(staking.withdraw(10_000_000_000, stakeId)).to.be.revertedWith("Can't withdraw more than you have");

        expect((await staking.getDepositInfo(stakeId))._stake).to.equal(ethers.BigNumber.from("999999999999990000")); // 1 reward (285) per hour

        // get user deposits ids
        const userDeposits = await staking.getDepositIds(ownerAddress);
        expect(userDeposits.length).to.equal(1);
        expect(userDeposits[0]).to.equal(stakeId);

    });

    it("Should stake 10_000_000 tokens, advance time 1y, add another token", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60 * 24 * 7 * 4;
        
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 86400; // 60 * 60 * 24 
        // rewardTimer = 3600; // 60 * 60 

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        const stake = await staking.deposit(ethers.BigNumber.from(10).pow(18), 0, kondux.address);
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
        
        await helpers.time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour
        
        // expect(staking.withdraw(10_000, stakeId)).to.be.revertedWith("Timelock not passed");

        await helpers.time.increase(timeIncrease);

        const withdraw = await staking.withdraw(10_000, stakeId);
        const withdrawReceipt = await withdraw.wait();
        const withdrawEvent = withdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent?.args?.liquidAmount).to.equal(9900); // 1 reward per hour
        // check totalstaked
        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(0);
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(0);

        // Add another token and stake it
        const newToken = await staking.addNewStakingToken(kondux2.address, 25, 60 * 60 * 24, 100, 1_000, 500, 10_000, 10_000_000);
        const newTokenReceipt = await newToken.wait();
        const newTokenEvent = newTokenReceipt.events?.find((e) => e.event === "NewAuthorizedERC20");
        const newTokenId = newTokenEvent?.args?.token;
        expect(newTokenId).to.equal(kondux2.address);

        const approve2 = await kondux2.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve2.wait();

        const setupApproval = await treasury.erc20ApprovalSetup(kondux2.address, ethers.BigNumber.from(10).pow(38));
        await setupApproval.wait();

        console.log("Account balance 7:", await kondux2.balanceOf(ownerAddress) + " KNDX2");

        const stake2 = await staking.deposit(ethers.BigNumber.from(10).pow(18), 0, kondux2.address);
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
        
        await helpers.time.increase(timeIncrease);

        expect(await staking.compoundRewardsTimer(stakeId2)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress, stakeId2)).to.be.closeTo(ethers.BigNumber.from(10).pow(18).div(4).div(12), ethers.BigNumber.from(10).pow(16)); // 1 reward per hour
        

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        await helpers.time.increase(timeIncrease);
        
        const withdraw2 = await staking.withdraw(10_000, stakeId2);
        const withdrawReceipt2 = await withdraw2.wait();
        const withdrawEvent2 = withdrawReceipt2.events?.find((e) => e.event === "Withdraw");
        expect(withdrawEvent2?.args?.liquidAmount).to.equal(9900); // 1 reward per hour

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getTotalStaked(kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux2.address)).to.equal(ethers.BigNumber.from(10).pow(18).sub(10_000));

    });

    it("Should stake 10_000_000 tokens, advance time to half of the timelock, and withdraw `toWithdraw` with penalty", async function () {
        snapshot.restore();
        const halfTimeIncrease = 60 * 60 * 24 * 365 / 2; // Half of the timelock period

        const toWithdraw = 10_000_000;
        const stakeAmount = ethers.BigNumber.from(10).pow(18);
    
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        expect(await helix.balanceOf(ownerAddress)).to.equal(0);
    
        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");
    
        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();
    
        const stake = await staking.deposit(stakeAmount, 3, kondux.address);
        const stakeReceipt = await stake.wait();
    
        expect(await staking.getTotalStaked(kondux.address)).to.equal(stakeAmount); 
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(stakeAmount);
    
        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;
    
        console.log("Stake id:", stakeId);
    
        const depositInfo = await staking.getDepositInfo(stakeId);
        expect(depositInfo._stake).to.equal(stakeAmount);
    
        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        // expect to revert if trying to withdraw before timelock
        expect(staking.withdraw(10_000, stakeId)).to.be.reverted;
    
        await helpers.time.increase(halfTimeIncrease);

        const helixBalanceBefore = await helix.balanceOf(ownerAddress);
        const konduxERC20Ratio = await staking.getRatioERC20(kondux.address);

        expect(helixBalanceBefore).to.equal(stakeAmount.mul(konduxERC20Ratio).mul(1e9));

        // Add a function for early withdrawal with penalty
        const earlyWithdraw = await staking.earlyUnstake(toWithdraw, stakeId);
        const earlyWithdrawReceipt = await earlyWithdraw.wait();
        const earlyWithdrawEvent = earlyWithdrawReceipt.events?.find((e) => e.event === "Withdraw");
        expect(earlyWithdrawEvent?.args?.liquidAmount).to.be.closeTo(toWithdraw * 0.94, 100_000); // 5% penalty

        const helixBalanceAfter = await helix.balanceOf(ownerAddress);

        expect(helixBalanceAfter).to.equal(helixBalanceBefore.sub(ethers.BigNumber.from(toWithdraw).mul(konduxERC20Ratio).mul(1e9)));
    
        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");
    
        expect((await kondux.balanceOf(ownerAddress)).mod(toWithdraw)).to.be.closeTo(toWithdraw * 0.99 * 0.95, 100_000); // 5% penalty
    
        expect((await staking.getDepositInfo(stakeId))._stake).to.equal(ethers.BigNumber.from(10).pow(18).sub(toWithdraw)); // Subtract the withdrawn amount
    
        // Get user deposits ids
        const userDeposits = await staking.getDepositIds(ownerAddress);
        expect(userDeposits.length).to.equal(1);
        expect(userDeposits[0]).to.equal(stakeId);
    });
    
    it("Should test treasury withdraw", async function () {
        snapshot.restore();
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");
        console.log("Account balance 6:", await kondux.balanceOf(treasury.address) + " KNDX");
        expect(await kondux.balanceOf(ownerAddress)).to.equal(ethers.BigNumber.from(10).pow(29).sub(ethers.BigNumber.from(10).pow(28)));
        expect(await kondux.balanceOf(treasury.address)).to.equal(ethers.BigNumber.from(10).pow(28));
        const treasuryWithdrawERC20 = await treasury.withdraw(ethers.BigNumber.from(10).pow(28), kondux.address);
        await treasuryWithdrawERC20.wait();
        expect(await kondux.balanceOf(ownerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));
        expect(await kondux.balanceOf(treasury.address)).to.equal(0);
        //print Withdrawal event looking for it's present in the receipt 
        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");
        console.log("Account balance 8:", await kondux.balanceOf(treasury.address) + " KNDX");

        const depositAgain = await treasury.deposit(ethers.BigNumber.from(10).pow(28), kondux.address);
        await depositAgain.wait();
        expect(await kondux.balanceOf(ownerAddress)).to.equal(ethers.BigNumber.from(10).pow(29).sub(ethers.BigNumber.from(10).pow(28)));
        expect(await kondux.balanceOf(treasury.address)).to.equal(ethers.BigNumber.from(10).pow(28));
        console.log("Account balance 9:", await kondux.balanceOf(ownerAddress) + " KNDX");
        console.log("Account balance 10:", await kondux.balanceOf(treasury.address) + " KNDX");
    
    });

    it("Should stake 10_000_000 tokens, advance time 1 day and restake rewards", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60; // 1 hour
        const [owner] = await ethers.getSigners();
        const ownerAddress = await owner.getAddress();

        let rewardTimer = 60 * 60 * 24;  //86400
        // rewardTimer = 3600; // 60 * 60 

        const stakeAmount = ethers.BigNumber.from(10).pow(18);
        const withdrawAmount = ethers.BigNumber.from(10).pow(7);
        const stakerInitialBalance = await kondux.balanceOf(ownerAddress);

        console.log("Account balance 5:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const approve = await kondux.approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();

        expect(await helix.balanceOf(ownerAddress)).to.equal(0);

        const stake = await staking.deposit(stakeAmount, 3, kondux.address);
        const stakeReceipt = await stake.wait();

        expect(await staking.getTotalStaked(kondux.address)).to.equal(stakeAmount); 
        expect(await staking.getUserTotalStakedByCoin(ownerAddress, kondux.address)).to.equal(stakeAmount);

        const helixRatio = await staking.getRatioERC20(kondux.address);
        expect(await helix.balanceOf(ownerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);

        const depositInfo = await staking.getDepositInfo(stakeId);
        expect(depositInfo._stake).to.equal(stakeAmount);

        console.log("Account balance 6:", await kondux.balanceOf(ownerAddress) + " KNDX");

        // expect(await staking.compoundRewardsTimer(stakeId)).to.equal(rewardTimer); DEPRECATED
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards
        
        await helpers.time.increase(timeIncrease);

        // expect(await staking.compoundRewardsTimer(stakeId)).to.equal(60 * 60 * 23); // rewards DEPRECATED
        console.log("+++++++++++++ REWARDS:", await staking.calculateRewards(ownerAddress, stakeId));
        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.be.closeTo(stakeAmount.div(4).div(12).div(30).div(24), ethers.BigNumber.from(10).pow(13)); // 1 reward per hour 
        
        // expect(staking.withdraw(withdrawAmount, stakeId)).to.be.revertedWith("Timelock not passed");

        await helpers.time.increase(timeIncrease);

        const helixBalance = await helix.balanceOf(ownerAddress);
        // expect(helixBalance).to.equal();

        const expectedRewards = (await staking.getDepositInfo(stakeId))._unclaimedRewards;

        expect(await helix.balanceOf(ownerAddress)).to.equal(stakeAmount.mul(helixRatio).mul(1e9));

        console.log("************* Helix balance 3:", await helix.balanceOf(ownerAddress));

        const stakeRewards = await staking.stakeRewards(stakeId);
        const stakeRewardsReceipt = await stakeRewards.wait();

        const stakeRewardsEvent = stakeRewardsReceipt.events?.filter((e) => e.event === "Compound")[0];
        const stakeRewardsAmount = stakeRewardsEvent?.args?.amount;

        console.log("Stake rewards:", stakeRewardsAmount);
        expect(stakeRewardsAmount).to.be.closeTo(expectedRewards, ethers.BigNumber.from(10).pow(10)); // 1 reward per hour

        expect(await staking.getStakedAmount(stakeId)).to.equal(stakeAmount.add(stakeRewardsAmount)); 

        expect(await staking.calculateRewards(ownerAddress, stakeId)).to.equal(0); // 0 rewards

        expect(await helix.balanceOf(ownerAddress)).to.equal(helixBalance.add(stakeRewardsAmount.mul(helixRatio).mul(1e9)));
        console.log("************* Helix balance 4:", await helix.balanceOf(ownerAddress));

    });

    it("Should stake 10_000_000 tokens, advance time and get multiple rewards", async function () {
        snapshot.restore();
        timeIncrease = 60 * 60; // 1 hour

        console.log("%%%% TIME 1: ", await helpers.time.latest());

        const [owner, staker] = await ethers.getSigners();
        const stakerAddress = await staker.getAddress();

        await console.log("Rewarded token 1:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 1:", await staking.getUserTotalRewardsByCoin( stakerAddress, kondux.address) + " KNDX");

        expect(await kondux.balanceOf(stakerAddress)).to.equal(0);

        const mint = await kondux.connect(staker).faucet();
        await mint.wait();

        expect(await kondux.balanceOf(stakerAddress)).to.equal(ethers.BigNumber.from(10).pow(29));

        console.log("Account balance 5:", await kondux.balanceOf(stakerAddress) + " KNDX");

        const approve = await kondux.connect(staker).approve(staking.address, ethers.BigNumber.from(10).pow(28));
        await approve.wait();
        
        const stake = await staking.connect(staker).deposit(ethers.BigNumber.from(10).pow(18), 4, kondux.address);
        const stakeReceipt = await stake.wait();

        await console.log("Rewarded token 2:", await staking.getTotalRewards(kondux.address) + " KNDX");
        await console.log("Rewarded  user 2:", await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");

        expect(await staking.getTotalStaked(kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18)); 
        expect(await staking.getUserTotalStakedByCoin(stakerAddress, kondux.address)).to.equal(ethers.BigNumber.from(10).pow(18));

        const stakeEvent = stakeReceipt.events?.filter((e) => e.event === "Stake")[0];
        const stakeId = stakeEvent?.args?.id;

        console.log("Stake id:", stakeId);
    
        const numberOfClaims = 3; // Number of times to claim rewards
    
        for (let i = 1; i <= numberOfClaims; i++) {
            console.log(`%%%% TIME BEFORE CLAIM ${i}: `, await helpers.time.latest());
            await helpers.time.increase(timeIncrease);
            console.log(`%%%% TIME AFTER CLAIM ${i}: `, await helpers.time.latest());
    
            const claimRewards = await staking.connect(staker).claimRewards(stakeId);
            const claimReceipt = await claimRewards.wait();
            const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
    
            // Check the rewards after each claim
            expect(claimEvent?.args?.netRewards).to.be.closeTo(
                ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(i),
                ethers.BigNumber.from(10).pow(13).mul(i)
            );
    
            // Check the total user and system rewards after each claim
            expect(await staking.connect(staker).getUserTotalRewardsByCoin(stakerAddress, kondux.address)).to.be.closeTo(
                ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(i),
                ethers.BigNumber.from(10).pow(13).mul(i)
            );
            expect(await staking.connect(staker).getTotalRewards(kondux.address)).to.be.closeTo(
                ethers.BigNumber.from(10).pow(18).div(4).div(12).div(30).div(24).mul(i),
                ethers.BigNumber.from(10).pow(13).mul(i)
            );
    
            console.log(`Rewarded token after claim ${i}:`, await staking.getTotalRewards(kondux.address) + " KNDX");
            console.log(`Rewarded user after claim ${i}:`, await staking.getUserTotalRewardsByCoin(stakerAddress, kondux.address) + " KNDX");
        }
    
        // Check the final account balance
        expect((await kondux.connect(staker).balanceOf(stakerAddress))).to.be.closeTo(
            ethers.BigNumber.from(10).pow(29).sub(ethers.BigNumber.from(10).pow(18).mul(numberOfClaims)),
            ethers.BigNumber.from(10).pow(17)
        );
    
    });
    


});
