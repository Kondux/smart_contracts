const { expect } = require("chai");
const { ethers, ignition } = require("hardhat");

import KNFTModule from "../ignition/modules/KNFTModule";
import Minter_BundleModule from "../ignition/modules/Minter_BundleModule";
import KBoxModule from '../ignition/modules/KBoxModule';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe("MinterBundle", () => {
  async function deployModuleFixture() {
    const minter = await ignition.deploy(Minter_BundleModule);
    const knft = await ignition.deploy(KNFTModule);
    const kbox = await ignition.deploy(KBoxModule);

    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    
    const setKNFT = await minter.minterBundle.setKNFT(knft.kondux);
    await setKNFT.wait();
    
    const grantRole = await knft.kondux.grantRole(MINTER_ROLE, minter.minterBundle);
    await grantRole.wait();
    
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();

    return { minter, knft, kbox, owner, ownerAddress };
  }
  
  beforeEach(async () => {
    // Set up initial conditions or deployments here
  });

  afterEach(async () => {
    // Clean up any modifications made in the beforeEach hook
  });

  it("should buy KNFT with Ether", async () => {    
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    await expect(minter.minterBundle.publicMint({value: ethers.parseEther("0.00001")})).to.be.revertedWith("Not enough ETH sent");

    // More Ether does not mean more KNFT
    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("2.5")});
    await mint2.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(10);
    for (let index = 5; index < 10; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
  });

  // it("should buy KNFT with kBox", async () => {    
  //   const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

  //   const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
  //   await mint.wait();

  //   // console.log(mint);
  //   expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
  //   for (let index = 0; index < 5; index++) {
  //     expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
  //   }
      
  // });

});