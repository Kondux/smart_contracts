// test/kndxMinting.test.js
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Known Deployed Contracts / Addresses on Mainnet (fork):
const KNDX_PAYMENT_TOKEN = "0x7ca5af5ba3472af6049f63c1abc324475d44efc1"; // KNDX ERC20 token
const ORIGINAL_OWNER_ADDRESS = "0x1e78aBEc10E007d44613C2CF3FD91091795A3812";
const ORIGINAL_TAX_WALLET = "0x79BD02b5936FFdC5915cB7Cd58156E3169F4F569";
const TOKEN_HOLDER_ADDRESS = "0x4936167DAE4160E5556D9294F2C78675659a3B63";
const FOUNDERS_PASS_HOLDER_ADDRESS = "0x26fC1CB1CDFc964E5458c8986a31c3F8A638c178";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const FOUNDERSPASS_ADDRESS = "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b";
const ORIGINAL_CONTRACT_OWNER = "0x41bc231d1e2eb583c24cee022a6cbce5168c9fd2";

// You need to provide these addresses from your environment or known deployed contracts:
const KNFT_ADDRESS = "0x5aD180dF8619CE4f888190C3a926111a723632ce" // Kondux NFT contract address
const TREASURY_ADDRESS = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E"; // Treasury contract address implementing ITreasury
const UNISWAP_PAIR_ADDRESS = "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72"; // Uniswap V2 pair address for (WETH-KNDX) or similar

describe("KonduxTokenBasedMinter - Token Minting (Buy) Function Tests", function () {
  async function deployFixture() {
    // Impersonate the original contract owner (admin)
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ORIGINAL_OWNER_ADDRESS],
    });
    const ownerSigner = await ethers.getSigner(ORIGINAL_OWNER_ADDRESS);

    // Fund the impersonated owner if needed
    const [funder] = await ethers.getSigners();
    const ownerBalance = await ethers.provider.getBalance(ORIGINAL_OWNER_ADDRESS);
    if (ownerBalance < ethers.parseEther("1")) {
      await funder.sendTransaction({
        to: ORIGINAL_OWNER_ADDRESS,
        value: ethers.parseEther("1.0"),
      });
    }

    // Deploy the KonduxTokenBasedMinter contract with provided addresses
    const MinterFactory = await ethers.getContractFactory("KonduxTokenBasedMinter", ownerSigner);
    const minter = await MinterFactory.deploy(
      KNFT_ADDRESS,
      FOUNDERSPASS_ADDRESS,
      TREASURY_ADDRESS,
      KNDX_PAYMENT_TOKEN,
      UNISWAP_PAIR_ADDRESS,
      WETH_ADDRESS
    );
    await minter.waitForDeployment();

    console.log("KonduxTokenBasedMinter deployed at:", minter.target);

    // Unpause the minter so we can run publicMint()
    await minter.setPaused(false);
    console.log("Minter unpaused.");

    // Impersonate token holder (user without Founder's Pass)
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [TOKEN_HOLDER_ADDRESS],
    });
    const tokenHolderSigner = await ethers.getSigner(TOKEN_HOLDER_ADDRESS);

    // Impersonate Founder's Pass holder
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [FOUNDERS_PASS_HOLDER_ADDRESS],
    });
    const foundersPassHolderSigner = await ethers.getSigner(FOUNDERS_PASS_HOLDER_ADDRESS);

    // Get contract instances
    const paymentToken = await ethers.getContractAt("IKonduxERC20", await minter.paymentToken(), tokenHolderSigner);
    const kNFTAddress = await minter.kNFT();
    const kNFT = await ethers.getContractAt("IKondux", kNFTAddress, ownerSigner);

    const foundersPassAddress = await minter.foundersPass();
    const foundersPass = await ethers.getContractAt("IERC721", foundersPassAddress, foundersPassHolderSigner);

    const decimals = await paymentToken.decimals();

    console.log("Fixture deployed successfully.");

    return {
      minter,
      ownerSigner,
      tokenHolderSigner,
      foundersPassHolderSigner,
      paymentToken,
      kNFT,
      foundersPass,
      decimals,
    };
  }

  it("Should apply standard price (no Founder's Pass) when minting NFTs", async function () {
    const {
      minter,
      tokenHolderSigner,
      paymentToken,
      kNFT,
      decimals,
    } = await loadFixture(deployFixture);

    const buyerAddress = tokenHolderSigner.address;
    console.log("Buyer address:", buyerAddress);
    const initialBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    console.log(`Buyer's initial token balance: ${ethers.formatUnits(initialBuyerTokenBalance, decimals)} TOKEN`);
    const initialBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);
    console.log(`Buyer's initial NFT balance: ${initialBuyerNFTBalance} NFT`);

    // The test logic assumes standard (no pass) = discountPrice
    const discountPrice = await minter.discountPrice();
    console.log(`Standard discount price (no founder pass): ${ethers.formatEther(discountPrice)} ETH`);

    // Calculate required tokens for that price
    const tokensRequired = await minter.getTokenAmountForETH(discountPrice);
    console.log("Tokens decimal places:", decimals);
    console.log(`Tokens required: ${ethers.formatUnits(tokensRequired, decimals)} TOKEN`);

    // Approve tokens
    console.log("Approving payment token for minter...");
    await paymentToken.connect(tokenHolderSigner).approve(minter.target, tokensRequired * 2n);
    console.log("Payment token approved.");
    const tokenAllowance = await paymentToken.allowance(buyerAddress, minter.target);
    console.log(`Token allowance: ${ethers.formatUnits(tokenAllowance, decimals)} TOKEN`);

    // Add minter to minters list in Kondux NFT contract using OpenZeppelin's AccessControl with keccak256("MINTER_ROLE") using ORIGINAL_CONTRACT_OWNER wallet;
    console.log("Adding minter to minters list...");
    const minterRole = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    // Impersonate the original contract owner (admin)
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ORIGINAL_CONTRACT_OWNER],
    });
    const contractOwnerSigner = await ethers.getSigner(ORIGINAL_CONTRACT_OWNER);
    await kNFT.connect(contractOwnerSigner).grantRole(minterRole, minter.target);
    console.log("Minter added to minters list.");

    // Mint NFTs
    const tx = await minter.connect(tokenHolderSigner).publicMint();
    const receipt = await tx.wait();
    console.log("publicMint transaction hash:", receipt.transactionHash);

    const finalBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    const finalBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);
    const bundleSize = await minter.bundleSize();

    // The difference in buyer tokens should be at least tokensRequired
    expect(finalBuyerTokenBalance).to.equal(initialBuyerTokenBalance.sub(tokensRequired));
    // NFT balance should increase by bundleSize
    expect(finalBuyerNFTBalance).to.equal(initialBuyerNFTBalance.add(bundleSize));
    console.log(`Buyer received ${bundleSize} NFT(s).`);
  });

  it("Should apply founder discount price when user has a Founder's Pass", async function () {
    const {
      minter,
      foundersPassHolderSigner,
      paymentToken,
      kNFT,
      foundersPass,
      decimals,
    } = await loadFixture(deployFixture);

    const buyerAddress = foundersPassHolderSigner.address;
    const foundersPassBalance = await foundersPass.balanceOf(buyerAddress);
    expect(foundersPassBalance).to.be.gt(0, "User does not have a Founder's Pass");

    const initialBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    const initialBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);

    const founderDiscountPrice = await minter.founderDiscountPrice();
    console.log(`Founder's discount price: ${ethers.formatEther(founderDiscountPrice)} ETH`);

    const tokensRequired = await minter.getTokenAmountForETH(founderDiscountPrice);
    console.log(`Tokens required (founder discount): ${ethers.formatUnits(tokensRequired, decimals)} TOKEN`);

    await paymentToken.connect(foundersPassHolderSigner).approve(minter.target, tokensRequired);

    const tx = await minter.connect(foundersPassHolderSigner).publicMint();
    const receipt = await tx.wait();
    console.log("publicMint (with Founder's Pass) transaction hash:", receipt.transactionHash);

    const finalBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    const finalBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);
    const bundleSize = await minter.bundleSize();

    expect(finalBuyerTokenBalance).to.equal(initialBuyerTokenBalance.sub(tokensRequired));
    expect(finalBuyerNFTBalance).to.equal(initialBuyerNFTBalance.add(bundleSize));
    console.log(`Buyer received ${bundleSize} NFT(s) with founder discount.`);
  });

  it("Should fail if user tries to mint without sufficient tokens despite approval", async function () {
    const {
      minter,
      tokenHolderSigner,
      paymentToken,
      kNFT,
      decimals,
    } = await loadFixture(deployFixture);

    const buyerAddress = tokenHolderSigner.address;
    const initialBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    const initialBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);

    // Let's assume the user tries to approve more than they have
    const largeAmount = initialBuyerTokenBalance.add(ethers.parseUnits("1", decimals));
    await paymentToken.connect(tokenHolderSigner).approve(minter.address, largeAmount);

    try {
      await minter.connect(tokenHolderSigner).publicMint();
      expect.fail("Mint should have failed due to insufficient token balance.");
    } catch (error) {
      expect(error.message).to.include("Insufficient token balance");
      console.log("Mint failed as expected due to insufficient token balance.");
    }

    // Check balances remain unchanged
    const finalBuyerTokenBalance = await paymentToken.balanceOf(buyerAddress);
    const finalBuyerNFTBalance = await kNFT.balanceOf(buyerAddress);

    expect(finalBuyerTokenBalance).to.equal(initialBuyerTokenBalance);
    expect(finalBuyerNFTBalance).to.equal(initialBuyerNFTBalance);
    console.log("Balances remain unchanged after failed mint attempt.");
  });
});
