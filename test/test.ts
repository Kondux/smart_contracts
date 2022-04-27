const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const provider = waffle.provider;

import {
  Authority,
  Authority__factory,
  Kondux,
  Minter,
} from "../types";
 
describe("Token contract", function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
  });
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const onwerAddress = await owner.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerBalance = await kondux.balanceOf(onwerAddress);
    expect(await kondux.totalSupply()).to.equal(ownerBalance);
  });
});

describe("BaseURI setup", async function () {
  let authority: Authority;
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
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
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
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
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
  });
  it("Should test mint NFT", async function () {
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const Kondux = await ethers.getContractFactory("Kondux");
    const kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const ownerAddress =  await owner.getAddress();
    const chainid = (await provider.getNetwork()).chainId;
    const {randomBytes} = await import('crypto');
    const dna = randomBytes(32);

    const baseURIString = "http://test.com/";
    const newBaseURI = await kondux.setBaseURI(baseURIString);
    await newBaseURI.wait();    
   
    describe ("Owner Mint NFT", async function () {
  
      it("Owner Should mint NFT", async function () {       
        const minted = await kondux.safeMint(ownerAddress,dna);
        await minted.wait();

        expect(await kondux.totalSupply()).to.equal(1);
        expect(await kondux.tokenURI(0)).to.equal(baseURIString + 0);
        expect(await kondux.tokenOfOwnerByIndex(ownerAddress, 0)).to.equal(0);
        expect(await kondux.indexDna(0)).to.equal(dna);
        expect(await kondux.ownerOf(0)).to.equal(ownerAddress);
      });

      it("Should mint NFT to second account", async function () {
        const minted = await kondux.safeMint(secondAddress,dna);
        await minted.wait();

        expect(await kondux.totalSupply()).to.equal(2);
        expect(await kondux.tokenURI(1)).to.equal(baseURIString + 1);
        expect(await kondux.tokenOfOwnerByIndex(secondAddress, 0)).to.equal(1);
        expect(await kondux.indexDna(1)).to.equal(dna);
        expect(await kondux.ownerOf(1)).to.equal(secondAddress);
      });

      it("Should change NFT dna", async function () {
        const newDna = randomBytes(32);
        const setDna = await kondux.setDna(0, newDna);
        await setDna.wait();

        expect(await kondux.indexDna(0)).to.equal(newDna);
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
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
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
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
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
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
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
        expect(await kondux.totalSupply()).to.equal(0);
        const Minter = await ethers.getContractFactory("Minter");
        const minter = await Minter.deploy(authority.address, kondux.address);
        const setMinter = await kondux.setMinter(minter.address);
        await setMinter.wait();
        const mintTransfer = await second.sendTransaction({to: minter.address, value: ethers.utils.parseEther("1.0")});
        await mintTransfer.wait();
        expect(await kondux.totalSupply()).to.equal(1);
        expect(await kondux.balanceOf(secondAddress)).to.equal(1);
      });
    });
  });
});

describe("WhiteList", async function () {
  let authority: Authority;
  let kondux: Kondux;
  let minter: Minter;
  const merkleProof = ["0xd8bed27f99ada543e3099439ea776b13b9deae301391f18c4cf9f191a201f2b5","0x0811888f707a155a69954b94074980d09e1fc7dddcf0efe1ddc6a39b99d05f9c","0x9437a772596137d3a133885f116ae67bd11177940cb3992a0f3a0aa6f90a36e7"];
  beforeEach(async function () {
    const [owner] = await ethers.getSigners();
    const onwerAddress = await owner.getAddress();
    authority = await new Authority__factory(owner).deploy(
      onwerAddress,
      onwerAddress,
      onwerAddress,
      onwerAddress
    );
    const Kondux = await ethers.getContractFactory("Kondux");
    kondux = await Kondux.deploy("Kondux NFT", "KDX", authority.address);
    const Minter = await ethers.getContractFactory("Minter");
    minter = await Minter.deploy(authority.address, kondux.address);
    const setMinter = await kondux.setMinter(minter.address);
    await setMinter.wait();
    const root = await minter.setRoot("0x09d6d1856fc7fe679bc4ba95045ff67408d0bb274594180f0afffa6f46e5132d");
    await root.wait();
  });
  it("Should test WhiteList minting", async function () {	
    const [owner, second] = await ethers.getSigners();
    const secondAddress = await second.getAddress();
    const ownerAddress =  await owner.getAddress();
 
    expect(await kondux.totalSupply()).to.equal(0);
    expect(await kondux.balanceOf(ownerAddress)).to.equal(0);
    expect(await kondux.balanceOf(secondAddress)).to.equal(0);

    const whiteList = await minter.whitelistMint(merkleProof);
    await whiteList.wait();
    expect(await kondux.totalSupply()).to.equal(1);
    expect(await kondux.balanceOf(ownerAddress)).to.equal(1);
    expect(await kondux.balanceOf(secondAddress)).to.equal(0);

    const whiteList2 = minter.connect(second).whitelistMint(merkleProof);
    await expect(whiteList2).to.be.reverted;
    expect(await kondux.totalSupply()).to.equal(1);
    expect(await kondux.balanceOf(ownerAddress)).to.equal(1);
    expect(await kondux.balanceOf(secondAddress)).to.equal(0);
  });
});