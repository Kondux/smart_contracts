import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import axios from 'axios';
// import { Treasury, KonduxERC20 } from '../types';
const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");

import {
  Authority,
  Authority__factory,
  KonduxFounders,
  KonduxFounders__factory,
  MinterFounders,
  MinterFounders__factory,
  Treasury,
  Treasury__factory,
} from "../types";
import { keccak256 } from 'ethers/lib/utils';
 
const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

describe("Whitelist minting", async function () {
  let authority: Authority;
  let treasury: Treasury;
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
  });
  it("Should mint whitelisted 020 NFT", async function () {
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();

    const provider = ethers.getDefaultProvider();

    const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
    const konduxFounders = await KonduxFounders.deploy("Kondux Founders NFT", "fKDX", authority.address);

    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux", "KDX", authority.address);

    const MinterFounders = await ethers.getContractFactory("MinterFounders");
    const minterFounders = await MinterFounders.deploy(authority.address, konduxFounders.address, kondux.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minterFounders.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const treasuryApprove = await treasury.setPermission(0, minterFounders.address, true);
    await treasuryApprove.wait();
    const treasurySpender = await treasury.setPermission(1, ownerAddress, true);
    await treasurySpender.wait();

    const rootRes = await axios.get(BASE_URL + "root020")
    const root020 = rootRes.data.root;
    const setRoot020 = await minterFounders.setRootFounders020(root020);
    await setRoot020.wait();

    expect(await minterFounders.rootFounders020()).to.equal(root020);
    expect(await konduxFounders.totalSupply()).to.equal(0);

    const price = await minterFounders.setPriceFounders020(ethers.utils.parseEther("0.2"));
    await price.wait();
    expect(await minterFounders.priceFounders020()).to.equal(ethers.utils.parseEther("0.2"));

    const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

    const res = await axios.get(BASE_URL + address + "/proof020");

    const data = res.data;
    const proof = data.response;
    
    await expect(minterFounders.whitelistMintFounders020(proof, {value: ethers.utils.parseEther("0.1")})).to.be.revertedWith("Not enought ether");

    const whitelistMint = await minterFounders.whitelistMintFounders020(proof, {value: ethers.utils.parseEther("0.2")});
    await whitelistMint.wait();

    expect(await konduxFounders.totalSupply()).to.equal(1);
    expect(await konduxFounders.balanceOf(address)).to.equal(1);

    await expect(minterFounders.whitelistMintFounders020(proof, {value: ethers.utils.parseEther("0.2")})).to.be.revertedWith("Already claimed");


    const withdraw = await treasury.withdrawEther(ethers.utils.parseEther("0.2"));
    await withdraw.wait();
    // expect(await ethers.provider.getBalance(ownerAddress)).to.equal(ethers.utils.parseEther("100"));
  });

  it("Should mint whitelisted NFT 025", async function () {
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();

    const provider = ethers.getDefaultProvider();

    const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
    const konduxFounders = await KonduxFounders.deploy("Kondux Founders NFT", "fKDX", authority.address);

    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux", "KDX", authority.address);

    const MinterFounders = await ethers.getContractFactory("MinterFounders");
    const minterFounders = await MinterFounders.deploy(authority.address, konduxFounders.address, kondux.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minterFounders.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const treasuryApprove = await treasury.setPermission(0, minterFounders.address, true);
    await treasuryApprove.wait();
    const treasurySpender = await treasury.setPermission(1, ownerAddress, true);
    await treasurySpender.wait();

    const rootRes = await axios.get(BASE_URL + "root025")
    const root020 = rootRes.data.root;
    const setRoot020 = await minterFounders.setRootFounders025(root020);
    await setRoot020.wait();

    expect(await minterFounders.rootFounders025()).to.equal(root020);
    expect(await konduxFounders.totalSupply()).to.equal(0);

    const price = await minterFounders.setPriceFounders025(ethers.utils.parseEther("0.25"));
    await price.wait();
    expect(await minterFounders.priceFounders025()).to.equal(ethers.utils.parseEther("0.25"));

    const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

    const res = await axios.get(BASE_URL + address + "/proof025");

    const data = res.data;
    const proof = data.response;
    
    await expect(minterFounders.whitelistMintFounders025(proof, {value: ethers.utils.parseEther("0.2")})).to.be.revertedWith("Not enought ether");

    const whitelistMint = await minterFounders.whitelistMintFounders025(proof, {value: ethers.utils.parseEther("0.25")});
    await whitelistMint.wait();

    expect(await konduxFounders.totalSupply()).to.equal(1);
    expect(await konduxFounders.balanceOf(address)).to.equal(1);

    await expect(minterFounders.whitelistMintFounders025(proof, {value: ethers.utils.parseEther("0.25")})).to.be.revertedWith("Already claimed");


    const withdraw = await treasury.withdrawEther(ethers.utils.parseEther("0.25"));
    await withdraw.wait();
    // expect(await ethers.provider.getBalance(ownerAddress)).to.equal(ethers.utils.parseEther("100"));
  });

  it.skip("Should mint whitelisted NFT Free Founders", async function () {  // Deprecated
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();

    const provider = ethers.getDefaultProvider();

    const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
    const konduxFounders = await KonduxFounders.deploy("Kondux Founders NFT", "fKDX", authority.address);

    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux", "KDX", authority.address);

    const MinterFounders = await ethers.getContractFactory("MinterFounders");
    const minterFounders = await MinterFounders.deploy(authority.address, konduxFounders.address, kondux.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minterFounders.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const treasuryApprove = await treasury.setPermission(0, minterFounders.address, true);
    await treasuryApprove.wait();
    const treasurySpender = await treasury.setPermission(1, ownerAddress, true);
    await treasurySpender.wait();

    const rootRes = await axios.get(BASE_URL + "rootFreeFounders");
    const root020 = rootRes.data.root;
    const setRoot020 = await minterFounders.setRootFreeFounders(root020);
    await setRoot020.wait();

    expect(await minterFounders.rootFreeFounders()).to.equal(root020);
    expect(await konduxFounders.totalSupply()).to.equal(0);

    const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

    const res = await axios.get(BASE_URL + address + "/proofFreeFounders");

    const data = res.data;
    const proof = data.response;

    const whitelistMint = await minterFounders.whitelistMintFreeFounders(proof);
    await whitelistMint.wait();

    expect(await konduxFounders.totalSupply()).to.equal(1);
    expect(await konduxFounders.balanceOf(address)).to.equal(1);

    await expect(minterFounders.whitelistMintFreeFounders(proof)).to.be.revertedWith("Already claimed");

  });

  it("Should mint whitelisted NFT Free Founders", async function () {
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();

    const provider = ethers.getDefaultProvider();

    const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
    const konduxFounders = await KonduxFounders.deploy("Kondux Founders NFT", "fKDX", authority.address);

    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux", "KDX", authority.address);

    const MinterFounders = await ethers.getContractFactory("MinterFounders");
    const minterFounders = await MinterFounders.deploy(authority.address, konduxFounders.address, kondux.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minterFounders.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const treasuryApprove = await treasury.setPermission(0, minterFounders.address, true);
    await treasuryApprove.wait();
    const treasurySpender = await treasury.setPermission(1, ownerAddress, true);
    await treasurySpender.wait();

    const rootRes = await axios.get(BASE_URL + "rootFreeKNFT")
    const root020 = rootRes.data.root;
    const setRoot020 = await minterFounders.setRootFreeKNFT(root020);
    await setRoot020.wait();

    expect(await minterFounders.rootFreeKNFT()).to.equal(root020);
    expect(await kondux.totalSupply()).to.equal(0);

    const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

    const res = await axios.get(BASE_URL + address + "/proofFreeKNFT");

    const data = res.data;
    const proof = data.response;

    const whitelistMint = await minterFounders.whitelistMintFreeKNFT(proof);
    await whitelistMint.wait();

    expect(await kondux.totalSupply()).to.equal(1);
    expect(await kondux.balanceOf(address)).to.equal(1);

    await expect(minterFounders.whitelistMintFreeKNFT(proof)).to.be.revertedWith("Already claimed");

  });

  it("Should mint from public minter contract", async function () {
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();

    const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
    const konduxFounders = await KonduxFounders.deploy("Kondux Founders NFT", "fKDX", authority.address);

    const MinterPublic = await ethers.getContractFactory("MinterPublic");
    const minterPublic = await MinterPublic.deploy(authority.address, konduxFounders.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minterPublic.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const treasuryApprove = await treasury.setPermission(0, minterPublic.address, true);
    await treasuryApprove.wait();
    const treasurySpender = await treasury.setPermission(1, ownerAddress, true);
    await treasurySpender.wait();

    expect(await konduxFounders.totalSupply()).to.equal(0);

    const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
    
    await expect(minterPublic.publicMint({value: ethers.utils.parseEther("0.2")})).to.be.revertedWith("Not enough ETH sent");

    const whitelistMint = await minterPublic.publicMint({value: ethers.utils.parseEther("0.25")});
    await whitelistMint.wait();

    expect(await konduxFounders.totalSupply()).to.equal(1);
    expect(await konduxFounders.balanceOf(address)).to.equal(1);

    const pause = await minterPublic.setPaused(true);
    await pause.wait();

    await expect(minterPublic.publicMint({value: ethers.utils.parseEther("0.25")})).to.be.revertedWith("Pausable: paused");

    const unpause = await minterPublic.setPaused(false);
    await unpause.wait();

    for (let i = 0; i < 649; i++) {
      const whitelistMint = await minterPublic.publicMint({value: ethers.utils.parseEther("0.25")});
      await whitelistMint.wait();
    }

    expect(await konduxFounders.totalSupply()).to.equal(650);
    expect(await konduxFounders.balanceOf(address)).to.equal(650);

    await expect(minterPublic.publicMint({value: ethers.utils.parseEther("0.25")})).to.be.revertedWith("No more NFTs left");

    const withdraw = await treasury.withdrawEther(ethers.utils.parseEther("0.25"));
    await withdraw.wait();
  });
});
