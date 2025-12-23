const { expect } = require("chai");
const { ethers, ignition } = require("hardhat");

import KNFTModule from "../ignition/modules/KNFTModule";
import Minter_BundleModule from "../ignition/modules/Minter_BundleModule";
import KBoxModule from '../ignition/modules/KBoxModule';
import Treasury from '../ignition/modules/TreasuryModule';
import FoundersModule from '../ignition/modules/FoundersModule';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import axios from 'axios';
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("MinterBundle", () => {
  async function deployModuleFixture() {
    const minter = await ignition.deploy(Minter_BundleModule);
    const knft = await ignition.deploy(KNFTModule);
    const kbox = await ignition.deploy(KBoxModule);
    const treasury = await ignition.deploy(Treasury);
    const founders = await ignition.deploy(FoundersModule);

    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    
    const setKNFT = await minter.minterBundle.setKNFT(knft.kondux);
    await setKNFT.wait();

    const setKBox = await minter.minterBundle.setKBox(kbox.kBox);
    await setKBox.wait();

    const setFounders = await minter.minterBundle.setFoundersPass(founders.founders);
    await setFounders.wait();

    const setTreasury = await minter.minterBundle.setTreasury(treasury.treasury);
    await setTreasury.wait();

    const treasuryPermission = await treasury.treasury.setPermission(0, minter.minterBundle, true);
    await treasuryPermission.wait();
    
    const grantRole = await knft.kondux.grantRole(MINTER_ROLE, minter.minterBundle);
    await grantRole.wait();    
    
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();

    return { minter, knft, kbox, owner, ownerAddress, treasury, founders };
  }
  
  beforeEach(async () => {
    // Set up initial conditions or deployments here
  });

  afterEach(async () => {
    // Clean up any modifications made in the beforeEach hook
  });

  it("should buy KNFT with Ether", async () => {    
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    const mintReceipt = await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    await expect(minter.minterBundle.publicMint({value: ethers.parseEther("0")})).to.be.revertedWith("Not enough ETH sent");

    await expect(minter.minterBundle.publicMint({value: ethers.parseEther("0.00001")})).to.be.revertedWith("Not enough ETH sent");

    // More Ether does not mean more KNFT
    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("2.5")});
    await mint2.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(10);
    for (let index = 5; index < 10; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
  });

  it("should buy KNFT with kBox", async () => {    
    const { minter, knft, kbox, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mintBox = await kbox.kBox.faucet();
    await mintBox.wait();

    expect(await kbox.kBox.balanceOf(ownerAddress)).to.equal(1);
    expect(await kbox.kBox.totalSupply()).to.equal(1);
    expect(await kbox.kBox.ownerOf(1)).to.equal(ownerAddress);

    await expect(minter.minterBundle.publicMintWithBox(0)).to.be.reverted;

    const approve = await kbox.kBox.approve(minter.minterBundle, 1);
    await approve.wait();

    const mint = await minter.minterBundle.publicMintWithBox(1);
    const mintReceipt = await mint.wait();

    expect(await kbox.kBox.balanceOf(ownerAddress)).to.equal(0);
    expect(await kbox.kBox.totalSupply()).to.equal(0);

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    await expect(minter.minterBundle.publicMintWithBox(1)).to.be.reverted;
      
  });

  it("Should set the price of KNFT", async () => {
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();    
    
    expect(await minter.minterBundle.price()).to.equal(ethers.parseEther("0.25"));

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    const setPrice = await minter.minterBundle.setPrice(ethers.parseEther("0.5"));
    const setPriceReceipt = await setPrice.wait();    

    expect(await minter.minterBundle.price()).to.equal(ethers.parseEther("0.5"));

    await expect(minter.minterBundle.publicMint({value: ethers.parseEther("0.25")})).to.be.revertedWith("Not enough ETH sent");

    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("0.5")});
    await mint2.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(10);
    for (let index = 5; index < 10; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
  });

  it("Should change the treasury address", async () => {
    const { minter, knft, treasury, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const treasuryMinterAddress = await minter.minterBundle.getTreasury();
    const treasuryContractAddress = await treasury.treasury.target;

    expect(treasuryMinterAddress).to.equal(treasuryContractAddress);

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    const treasury2 = await ignition.deploy(Treasury);
    const setTreasury = await minter.minterBundle.setTreasury(treasury2.treasury);
    const setTreasuryReceipt = await setTreasury.wait();

    const treasuryPermission = await treasury2.treasury.setPermission(0, minter.minterBundle, true);
    await treasuryPermission.wait();

    expect(await minter.minterBundle.getTreasury()).to.equal(treasury2.treasury);

    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint2.wait();

    expect(await ethers.provider.getBalance(treasury2.treasury)).to.equal(ethers.parseEther("0.25"));
  });

  it("Should change the kBox address", async () => {
    const { minter, knft, kbox, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const kBoxAddress = await minter.minterBundle.getKBox();
    const kBoxContractAddress = await kbox.kBox.target;

    expect(kBoxAddress).to.equal(kBoxContractAddress);

    const mintBox = await kbox.kBox.faucet();
    await mintBox.wait();

    expect(await kbox.kBox.balanceOf(ownerAddress)).to.equal(1);
    expect(await kbox.kBox.totalSupply()).to.equal(1);
    expect(await kbox.kBox.ownerOf(1)).to.equal(ownerAddress);

    await expect(minter.minterBundle.publicMintWithBox(0)).to.be.reverted;

    const approve = await kbox.kBox.approve(minter.minterBundle, 1);
    await approve.wait();

    const mint = await minter.minterBundle.publicMintWithBox(1);
    await mint.wait();

    expect(await kbox.kBox.balanceOf(ownerAddress)).to.equal(0);
    expect(await kbox.kBox.totalSupply()).to.equal(0);

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    const kbox2 = await ignition.deploy(KBoxModule);
    const setKBox = await minter.minterBundle.setKBox(kbox2.kBox);
    const setKboxReceipt = await setKBox.wait();

    expect(await minter.minterBundle.getKBox()).to.equal(kbox2.kBox);

    const mintBox2 = await kbox2.kBox.faucet();
    await mintBox2.wait();

    expect(await kbox2.kBox.balanceOf(ownerAddress)).to.equal(1);
    expect(await kbox2.kBox.totalSupply()).to.equal(1);
    expect(await kbox2.kBox.ownerOf(1)).to.equal(ownerAddress);

    await expect(minter.minterBundle.publicMintWithBox(0)).to.be.reverted;

    const approve2 = await kbox2.kBox.approve(minter.minterBundle, 1);
    await approve2.wait();

    const mint2 = await minter.minterBundle.publicMintWithBox(1);
    await mint2.wait();

    expect(await kbox2.kBox.balanceOf(ownerAddress)).to.equal(0);
    expect(await kbox2.kBox.totalSupply()).to.equal(0);

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(10);
    for (let index = 5; index < 10; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
  });

  it("Should change the KNFT address", async () => {
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const konduxAddress = await minter.minterBundle.getKNFT();
    const konduxContractAddress = await knft.kondux.target;

    expect(konduxAddress).to.equal(konduxContractAddress);

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    const knft2 = await ignition.deploy(KNFTModule);
    const setKNFT = await minter.minterBundle.setKNFT(knft2.kondux);
    const setKNTReceipt = await setKNFT.wait();

    const grantRole = await knft2.kondux.grantRole(ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")), minter.minterBundle);
    await grantRole.wait();

    expect(await minter.minterBundle.getKNFT()).to.equal(knft2.kondux);

    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint2.wait();

    expect(await knft2.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft2.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
  });

  it("Should change the bundle size", async () => {
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    const setBundleSize = await minter.minterBundle.setBundleSize(10);
    const setBundleSizeReceipt = await setBundleSize.wait();

    expect(await minter.minterBundle.bundleSize()).to.equal(10);

    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("0.5")});
    await mint2.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(15);
    for (let index = 5; index < 15; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }
    
    // Bundle size cannot be 0
    await expect(minter.minterBundle.setBundleSize(0)).to.be.reverted;

    // Bundle size cannot be greater than 15
    await expect(minter.minterBundle.setBundleSize(16)).to.be.reverted;

  });

  it("Should set the DNA of the KNFT after minting", async () => {
    const { minter, knft } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.getDna(index)).to.equal(0);
    }

    const setDNA = await knft.kondux.setDna(0, ethers.keccak256(ethers.toUtf8Bytes("NEW")));
    const setDNAReceipt = await setDNA.wait();

    expect(await knft.kondux.getDna(0)).to.equal(ethers.keccak256(ethers.toUtf8Bytes("NEW")));

  });

  it("Should set a Gene at a specific position", async () => {    
    const { minter, knft } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.readGene(index, 0, 1)).to.equal(0);
    }

    const setGene = await knft.kondux.writeGene(0, 1, 0, 1);
    const setGeneReceipt = await setGene.wait();   

    expect(await knft.kondux.readGene(0, 0, 1)).to.equal(1);

    // Set a gene at a position that does not exist
    await expect(knft.kondux.writeGene(0, 1, 40, 41)).to.be.reverted;

    // Set a gene at position 20 with 1 byte
    const setGene2 = await knft.kondux.writeGene(0, 1, 20, 21);
    await setGene2.wait();

    expect(await knft.kondux.readGene(0, 20, 21)).to.equal(1);

    // Set a Gene at position 10 with 5 bytes (ex.: 0x12593478ff)
    const setGene3 = await knft.kondux.writeGene(0, 0x12593478ff, 10, 15);
    await setGene3.wait();

    expect(await knft.kondux.readGene(0, 10, 15)).to.equal(0x12593478ff);
  });

  it("Should be able to transfer KNFT", async () => {
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    // set a random DNA for the first KNFT
    const setDNA = await knft.kondux.setDna(0, ethers.keccak256(ethers.toUtf8Bytes("NEW")));
    await setDNA.wait();

    const [ _, newOwner] = await ethers.getSigners();
    const newOwnerAddress = await newOwner.getAddress();

    expect(newOwnerAddress).to.not.equal(ownerAddress);

    const transfer = await knft.kondux.transferFrom(ownerAddress, newOwnerAddress, 0);
    await transfer.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(4);
    expect(await knft.kondux.balanceOf(newOwnerAddress)).to.equal(1);
    expect(await knft.kondux.ownerOf(0)).to.equal(newOwnerAddress);

    // DNA should be the same
    expect(await knft.kondux.getDna(0)).to.equal(ethers.keccak256(ethers.toUtf8Bytes("NEW")));

  });

  it("Should be able to set a new pause state", async () => {
    const { minter, knft } = await loadFixture(deployModuleFixture);

    expect(await minter.minterBundle.paused()).to.equal(true);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    expect(await minter.minterBundle.paused()).to.equal(false);

    const pause = await minter.minterBundle.setPaused(true);
    await pause.wait();

    expect(await minter.minterBundle.paused()).to.equal(true);
  });

  it("Should pause public minting", async () => {
    const { minter, knft, founders } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const knftActive = await minter.minterBundle.setPublicMintActive(true);
    await knftActive.wait();

    const burnFP = await founders.founders.burn(1);
    await burnFP.wait();

    const mint = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint.wait();

    const pause = await minter.minterBundle.setPublicMintActive(false);
    await pause.wait();

    const faucetFP = await founders.founders.faucet();
    await faucetFP.wait();

    // Still mintable with Founders Pass
    const mint2 = await minter.minterBundle.publicMint({value: ethers.parseEther("0.25")});
    await mint2.wait();

    const burnFoundersPass = await founders.founders.burn(2);
    await burnFoundersPass.wait();

    await expect(minter.minterBundle.publicMint({value: ethers.parseEther("0.25")})).to.be.revertedWith("kNFT minting is not active or you don't have a Founder's Pass");
  });

  it("Should pause minting with kBox", async () => {
    const { minter, kbox } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mintBox = await kbox.kBox.faucet();
    await mintBox.wait();

    const approve = await kbox.kBox.approve(minter.minterBundle, 1);
    await approve.wait();

    const mint = await minter.minterBundle.publicMintWithBox(1);
    await mint.wait();

    const pause = await minter.minterBundle.setKBoxMintActive(false);
    await pause.wait();

    await expect(minter.minterBundle.publicMintWithBox(1)).to.be.revertedWith("kBox minting is not active");
  });

  it("Should pause with Founders Pass", async () => {
    const { minter, founders } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const mint = await minter.minterBundle.publicMintWithFoundersPass(1);
    await mint.wait();

    const pause = await minter.minterBundle.setFoundersPassMintActive(false);
    await pause.wait();

    await expect(minter.minterBundle.publicMintWithFoundersPass(1)).to.be.revertedWith("Founder's Pass minting is not active");
  });

  it("Should have a whitelist root", async () => {
    const { minter } = await loadFixture(deployModuleFixture);

    const rootWhitelistBundleRes = await axios.get(BASE_URL + "rootWhitelistBundle");
    const rootWhitelistBundle = rootWhitelistBundleRes.data.root;

    expect(await minter.minterBundle.rootWhitelist()).to.equal(rootWhitelistBundle);
  });

  it("Should set a new whitelist root", async () => {
    const { minter } = await loadFixture(deployModuleFixture);

    const rootWhitelistBundleRes = await axios.get(BASE_URL + "rootWhitelistBundle");
    const rootWhitelistBundle = rootWhitelistBundleRes.data.root;

    const setWhitelistRoot = await minter.minterBundle.setWhitelistRoot(rootWhitelistBundle);
    await setWhitelistRoot.wait();

    expect(await minter.minterBundle.rootWhitelist()).to.equal(rootWhitelistBundle);    

    // should fail if not called by the owner
    const [_, newOwner] = await ethers.getSigners();
    const newOwnerAddress = await newOwner.getAddress();

    await expect(minter.minterBundle.connect(newOwner).setWhitelistRoot(rootWhitelistBundle)).to.be.reverted;
  });

  it("Should buy KNFT with whitelist", async () => {
    const { minter, knft, ownerAddress } = await loadFixture(deployModuleFixture);

    const unpause = await minter.minterBundle.setPaused(false);
    await unpause.wait();

    const response = await axios.get(BASE_URL + ownerAddress + "/proofWhitelistBundle");

    const data = response.data;
    const proof = data.response;

    await expect(minter.minterBundle.publicMintWhitelist(proof, {value: ethers.parseEther("0.1")})).to.be.reverted;

    const mint = await minter.minterBundle.publicMintWhitelist(proof, {value: ethers.parseEther("0.25")});
    await mint.wait();

    expect(await knft.kondux.balanceOf(ownerAddress)).to.equal(5);
    for (let index = 0; index < 5; index++) {
      expect(await knft.kondux.ownerOf(index)).to.equal(ownerAddress);
    }

    // should fail if not called by the owner
    const [_, newOwner] = await ethers.getSigners();
    const newOwnerAddress = await newOwner.getAddress();

    await expect(minter.minterBundle.connect(newOwner).publicMintWhitelist(proof, {value: ethers.parseEther("0.25")})).to.be.reverted;

    // should fail if whitelist is not active
    const pause = await minter.minterBundle.setWhitelistActive(false);
    await pause.wait();

    await expect(minter.minterBundle.publicMintWhitelist(proof, {value: ethers.parseEther("0.25")})).to.be.reverted;
    
  });

});