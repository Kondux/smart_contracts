import { Marketplace } from '../types/contracts/Marketplace';
import helpers from "@nomicfoundation/hardhat-network-helpers";
import axios from 'axios';
// import { Treasury, KonduxERC20 } from '../types';
const { expect } = require("chai");
const { ethers } = require("hardhat");

import {
  Authority,
  Authority__factory,
  Kondux,
  Kondux__factory,
  MinterPublic,
  MinterPublic__factory,
  KonduxERC20,
  KonduxERC20__factory,
  Treasury,
  Treasury__factory,
} from "../types";
import { keccak256 } from 'ethers/lib/utils';
import { KonduxFounders } from '../types/contracts/Kondux_Founders.sol/KonduxFounders';
 
describe("Token contract", function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const ownerAddress = await owner.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerBalance = await kondux.balanceOf(ownerAddress);
    expect(await kondux.totalSupply()).to.equal(ownerBalance);
  });
});

describe("BaseURI setup", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("BaseURI should start blank, will be changed later", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();

    const Kondux = await ethers.getContractFactory("Kondux");

    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);

    const baseURI = await kondux.baseURI();
    describe("Blank base URI", async function () {
      it("Should be blank", async function () {
        expect(baseURI).to.equal("");
      });
    });

    const baseURIString = "http://test.com";
    
    describe("New base URI", async function () {
      it("Should be baseURIString", async function () {
        const newBaseURI = await kondux.setBaseURI(baseURIString);
        await newBaseURI.wait();
        expect(await kondux.baseURI()).to.equal(baseURIString);
      });
    });

    describe("New base URI if second account", async function () {
      it("Should be reverted", async function () {
        const newBaseURI = kondux.connect(second).setBaseURI(baseURIString);
        await expect(newBaseURI).to.be.reverted;
      });
    });

  });
});

describe("Zero NFT", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Shouldn't have any NFT after deployment", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();

    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    expect(await kondux.totalSupply()).to.equal(0);
  });
});

describe ("Mint NFT", async function () {
  let authority: Authority;
  let konduxERC20: KonduxERC20;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    konduxERC20 = await new KonduxERC20__factory(owner).deploy();
    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Should test mint NFT", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerAddress =  await owner.getAddress();
    const chainid = (await ethers.provider.getNetwork()).chainId;
    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);

    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();    
   
    describe ("Owner Mint NFT", async function () {
  
      it("Owner Should mint NFT", async function () {
        let feeData = await ethers.provider.getGasPrice()
        console.log(feeData)
        feeData = feeData.mul(3)
        console.log(feeData)
        console.log(await ethers.provider.getGasPrice())
        // console.log(gasPrice.mul(2))       
        const minted = await kondux.safeMint(ownerAddress,dna, { gasPrice: feeData});
        console.log("******************");
        const receipt = await minted.wait();
        console.log("####################");
    ;

        expect(await kondux.totalSupply()).to.equal(1);
        expect(await kondux.tokenURI(0)).to.equal(baseURIString + 0);
        expect(await kondux.tokenOfOwnerByIndex(ownerAddress, 0)).to.equal(0);
        expect(await kondux.indexDna(0)).to.equal(ethers.BigNumber.from(dna));
        expect(await kondux.ownerOf(0)).to.equal(ownerAddress);
      });

      it("Should mint NFT to second account", async function () {
        const minted = await kondux.safeMint(secondAddress,dna);
        await minted.wait();

        expect(await kondux.totalSupply()).to.equal(2);
        expect(await kondux.tokenURI(1)).to.equal(baseURIString + 1);
        expect(await kondux.tokenOfOwnerByIndex(secondAddress, 0)).to.equal(1);
        expect(await kondux.indexDna(1)).to.equal(ethers.BigNumber.from(dna));
        expect(await kondux.ownerOf(1)).to.equal(secondAddress);
      });

      it("Should change NFT dna", async function () {
        const newDna = randomBytes(32);
        const setDna = await kondux.setDna(0, newDna);
        await setDna.wait();

        expect(await kondux.indexDna(0)).to.equal(ethers.BigNumber.from(newDna));
      });

      describe ("Second account Mint NFT", async function () {
        it("Second Shouldn't mint NFT", async function () {
          const minted = kondux.connect(second).safeMint(ownerAddress,dna);
          await expect(minted).to.be.reverted;
        });
      });
      
    });
  });
});

describe ("NFT Royalty", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );

    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Should set NFT", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerAddress =  await owner.getAddress();
    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);
 
    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();
    
    const minted = await kondux.safeMint(ownerAddress,dna);
    await minted.wait();

    const denominator = await kondux.changeDenominator(100);
    await denominator.wait();
    expect(await kondux.denominator()).to.equal(100);
    
    const setDefaultRoyalty = await kondux.setDefaultRoyalty(ownerAddress,50);
    await setDefaultRoyalty.wait();
    const royaltyInfo = await kondux.royaltyInfo(0,10000);
    expect(royaltyInfo[0]).to.equal(ownerAddress);
    expect(royaltyInfo[1]).to.equal(50);
  });

  it("Should not set denominator", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const denominator = kondux.connect(second).changeDenominator(100);
    await expect(denominator).to.be.reverted;
  });

  it("Should not set defaultRoyalty", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const setDefaultRoyalty = kondux.connect(second).setDefaultRoyalty(secondAddress,50);
    await expect(setDefaultRoyalty).to.be.reverted;
  });
});

describe ("Burn NFT", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );

    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Should test NFT burn", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerAddress =  await owner.getAddress();

    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);

    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();

    const minted = await kondux.safeMint(ownerAddress,dna);
    await minted.wait();

    describe ("Owner burn NFT", async function () {
      it("Owner Should NFT burn", async function () {
        
        expect(await kondux.totalSupply()).to.equal(1);
        const burned = await kondux.burn(0);
        await burned.wait();
        expect(await kondux.totalSupply()).to.equal(0);
      });
    });
    
    describe ("Second burn NFT", async function () {
      it("Second Shouldn't NFT burn", async function () {
        const burned = kondux.connect(second).burn(0);
        await expect(burned).to.be.reverted;
      });
    });
  });
});

describe('Send Ether to contract', async function () {
  let authority: Authority;
  let treasury: Treasury;
  let konduxERC20: KonduxERC20;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );

    konduxERC20 = await new KonduxERC20__factory(owner).deploy();

    treasury = await new Treasury__factory(owner).deploy(
      authority.address,
    );

    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
    
  });
  it('Should reject the transfer', async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);

    const transfer = second.sendTransaction({to: kondux.address, value: ethers.utils.parseEther("1.0")});
    await expect(transfer).to.be.reverted;
    describe("Sending Ether to Minter should mint NFT", async function () {
      it("Minter should mint NFT", async function () {
        const KonduxFounders = await ethers.getContractFactory("KonduxFounders");
        const konduxFounders = await KonduxFounders.deploy("NAME", "TICKER", authority.address);
        expect(await kondux.totalSupply()).to.equal(0);
        const Minter = await ethers.getContractFactory("MinterPublic");
        const minter = await Minter.deploy(authority.address, kondux.address, treasury.address);
        const pushMinterPublic = await authority.pushRole(minter.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
        await pushMinterPublic.wait();
        const setKF = await minter.setKonduxFounders(konduxFounders.address);
        await setKF.wait();
        const permission = await treasury.setPermission(0, minter.address, true);
        await permission.wait();
        const mintTransfer = await minter.connect(second).publicMint({value: ethers.utils.parseEther("1.0")});
        await mintTransfer.wait();
        expect(await konduxFounders.totalSupply()).to.equal(1);
        expect(await konduxFounders.balanceOf(secondAddress)).to.equal(1);
        expect(await ethers.provider.getBalance(treasury.address)).to.equal(ethers.utils.parseEther("1.0"));
      });
    });

  });
});

describe("Whitelist minting", async function () {
  let authority: Authority;
  let treasury: Treasury;
  let konduxERC20: KonduxERC20;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );

    konduxERC20 = await new KonduxERC20__factory(owner).deploy();

    treasury = await new Treasury__factory(owner).deploy(
      authority.address,
    );

    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it.skip("Should mint whitelisted NFT", async function () { // Deprecated
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);

    const Minter = await ethers.getContractFactory("MinterPublic");
    const minter = await Minter.deploy(authority.address, kondux.address, treasury.address);
    
    const pushMinter = await authority.pushRole(minter.address, keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    
    const rootRes = await axios.get("https://h7af1y611a.execute-api.us-east-1.amazonaws.com/root")
    const root = rootRes.data.root;
    const setRoot = await minter.setRoot(root);
    await setRoot.wait();

    expect(await minter.root()).to.equal(root);
    expect(await kondux.totalSupply()).to.equal(0);

    const res = await axios.get("https://h7af1y611a.execute-api.us-east-1.amazonaws.com/" + secondAddress + "/proof");

    const data = res.data;
    const proof = data.response;
    
    const whitelistMint = await minter.connect(second).whitelistMint(proof);
    await whitelistMint.wait();
    expect(await kondux.totalSupply()).to.equal(1);
    expect(await kondux.balanceOf(secondAddress)).to.equal(1);
  });
});

describe ("Burn NFT", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();
  });
  it("Should test NFT burn", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerAddress =  await owner.getAddress();

    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);

    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();

    const minted = await kondux.safeMint(ownerAddress,dna);
    await minted.wait();

    describe ("Owner burn NFT", async function () {
      it("Owner Should NFT burn", async function () {
        
        expect(await kondux.totalSupply()).to.equal(1);
        const burned = await kondux.burn(0);
        await burned.wait();
        expect(await kondux.totalSupply()).to.equal(0);
      });
    });
    
    describe ("Second burn NFT", async function () {
      it("Second Shouldn't NFT burn", async function () {
        const burned = kondux.connect(second).burn(0);
        await expect(burned).to.be.reverted;
      });
    });
  });
});


describe("Marketplace", async function () {
  let authority: Authority;
  let kondux: Kondux;
  let marketplace: Marketplace;
  beforeEach(async function () {
    const [owner, second] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();
    const secondAddress = await second.getAddress();
    authority = await new Authority__factory(owner).deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ownerAddress
    );
    const Kondux = await ethers.getContractFactory("Kondux");
    kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy(authority.address);

    const chainid = (await ethers.provider.getNetwork()).chainId;
    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);

    const pushMinter = await authority.pushRole(authority.governor(), keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")));
    await pushMinter.wait();

    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();
    const minted = await kondux.safeMint(ownerAddress, dna);
    await minted.wait();  

    
  });
  it("Should create ask ", async function () {	
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const ownerAddress =  await owner.getAddress();
 
    marketplace.createAsk([kondux.address], [0], [ethers.utils.parseEther("1.0")], [ownerAddress]);
    console.log(await kondux.balanceOf(ownerAddress));
    console.log(await marketplace.asks(ownerAddress, 0));
  });
});
