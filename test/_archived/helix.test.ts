const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HelixToken", () => {
  let HelixToken, helixToken, MinterContract, minterContract, admin, minter, burner, user1, user2, user3;

  beforeEach(async () => {
    HelixToken = await ethers.getContractFactory("Helix");
    helixToken = await HelixToken.deploy("Helix", "HLX");
    MinterContract = await ethers.getContractFactory("MinterContract");
    minterContract = await MinterContract.deploy();
    [admin, minter, burner, user1, user2, user3] = await ethers.getSigners();

    // Set up initial conditions or deployments here
  });

  afterEach(async () => {
    // Clean up any modifications made in the beforeEach hook
  });

  // ... (the rest of the tests)

  it("should work after adding the minter contract to the whitelist", async () => {
    await helixToken.connect(admin).setAllowedContract(minterContract.address, true);
    await helixToken.connect(admin).setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), minterContract.address, true);      
    await minterContract.mint(helixToken.address, user1.address, 100);
    await helixToken.connect(user1).approve(minterContract.address, 50);
    await expect(minterContract.connect(user1).transferTokens(helixToken.address, user1.address, user2.address, 50)).to.emit(helixToken, "Transfer").withArgs(user1.address, user2.address, 50);
  });

  it("should fail after revoking minter contract from the whitelist", async () => {
    await helixToken.connect(admin).setAllowedContract(minterContract.address, true);
    await helixToken.connect(admin).setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), minterContract.address, true);      
    await minterContract.mint(helixToken.address, user1.address, 100);
    await helixToken.connect(admin).setAllowedContract(minterContract.address, false);
    await helixToken.connect(user1).approve(minterContract.address, 50);
    await expect(minterContract.connect(user1).transferTokens(helixToken.address, user1.address, user2.address, 50)).to.be.revertedWith("HelixToken: direct transfers not allowed");
  });
});