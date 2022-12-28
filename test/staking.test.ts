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
} from "../types";
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("Staking minting", async function () {
    let authority: Authority;
    let treasury: Treasury;
    let staking: Staking;
    let kondux: KonduxERC20;
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

        staking = await new Staking__factory(owner).deploy(
            authority.address,
            kondux.address,
            treasury.address
        );
        await staking.deployed();
        console.log("Staking address:", staking.address);

        const setupApproval = await treasury.erc20ApprovalSetup(kondux.address, 100_000_000_000_000);
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

        const approve = await kondux.approve(treasury.address, 100_000_000_000_000);
        await approve.wait();
        console.log("Account balance 3:", await kondux.balanceOf(ownerAddress) + " KNDX");

        const deposit = await treasury.deposit(1_000_000_000_000, kondux.address);
        await deposit.wait();


        console.log("Account balance 4:", await kondux.balanceOf(ownerAddress) + " KNDX");
    });

    it("Should stake 10_000_000 tokens, advance time 1h and get first reward", async function () {
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


        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(3600); // 60 * 60 seconds
        expect(await staking.calculateRewards(ownerAddress)).to.equal(0); // 0 rewards
        
        await time.increase(60 *60); // 1 minute
        
        expect(await staking.compoundRewardsTimer(ownerAddress)).to.equal(0); // 0 rewards
        expect(await staking.calculateRewards(ownerAddress)).to.equal(285); // 1 reward per hour 

        const claimRewards = await staking.claimRewards();
        const claimReceipt = await claimRewards.wait();
        const claimEvent = claimReceipt.events?.find((e) => e.event === "Reward");
        expect(claimEvent?.args?.amount).to.equal(285); // 1 reward per hour

        console.log("Account balance 7:", await kondux.balanceOf(ownerAddress) + " KNDX");

        expect((await kondux.balanceOf(ownerAddress)).mod(1000)).to.equal(285); // 1 reward per hour


    });


});
