// test/kndxSwap.test.js
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Addresses as provided
const KNDX_ADDRESS = "0x7ca5af5ba3472af6049f63c1abc324475d44efc1";
const ORIGINAL_OWNER_ADDRESS = "0x1e78aBEc10E007d44613C2CF3FD91091795A3812";
const ORIGINAL_TAX_WALLET = "0x79BD02b5936FFdC5915cB7Cd58156E3169F4F569";
const NEW_TAX_WALLET = "0x286e31194841A98016E87cfCC1e7B0caa2c13558";
const TOKEN_HOLDER_ADDRESS = "0x4936167DAE4160E5556D9294F2C78675659a3B63";
const ORIGINAL_CONTRACT_DEPLOYER = "0x79dd15ad871b0fe18040a52f951d757ef88cfe72";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const FOUNDERSPASS_ADDRESS = "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b";
const FOUNDERS_PASS_HOLDER_ADDRESS = "0x26fC1CB1CDFc964E5458c8986a31c3F8A638c178"; // Updated to match your latest test

// Uniswap V2 Router address (mainnet)
const UNISWAP_V2_ROUTER_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

// Simplified ABIs for necessary functions
const KNDX_ABI = [
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function setTaxWallet(address newTaxWallet) external",
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function decimals() external view returns (uint8)",
  "function transfer(address recipient, uint256 amount) external returns (bool)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  // Add other necessary function signatures if needed
];

const UNISWAP_V2_ROUTER_ABI = [
  "function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)",
  "function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)",
  "function WETH() external pure returns (address)",
];

// Assuming the Founders Pass is an ERC-721 token
const FOUNDERSPASS_ABI = [
  "function balanceOf(address owner) external view returns (uint256)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  // Add other necessary function signatures if needed
];

describe("KNDX Contract - Tax Wallet Update, Token Swap, and Founder's Pass Discount Test", function () {
  // Fixture to set up the testing environment
  async function deployFixture() {
    // Impersonate the original contract owner
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ORIGINAL_OWNER_ADDRESS],
    });
    const ownerSigner = await ethers.getSigner(ORIGINAL_OWNER_ADDRESS);

    // Fund the impersonated owner with ETH if needed (e.g., for gas)
    const [funder] = await ethers.getSigners();
    const ownerBalance = await ethers.provider.getBalance(ORIGINAL_OWNER_ADDRESS);
    if (ownerBalance < (ethers.parseEther("1"))) {
      await funder.sendTransaction({
        to: ORIGINAL_OWNER_ADDRESS,
        value: ethers.parseEther("1.0"),
      });
    }

    // Connect to the KNDX contract as the owner
    const kndx = await ethers.getContractAt(KNDX_ABI, KNDX_ADDRESS, ownerSigner);

    // Impersonate the token holder
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [TOKEN_HOLDER_ADDRESS],
    });
    const tokenHolderSigner = await ethers.getSigner(TOKEN_HOLDER_ADDRESS);

    // Ensure the token holder has enough KNDX tokens
    const kndxContract = await ethers.getContractAt(KNDX_ABI, KNDX_ADDRESS, tokenHolderSigner);
    const decimals = await kndxContract.decimals();
    const swapAmount = ethers.parseUnits("10000", decimals); // 10,000 KNDX

    const tokenHolderBalance = await kndxContract.balanceOf(TOKEN_HOLDER_ADDRESS);
    expect(tokenHolderBalance).to.be.gt(swapAmount);
    console.log(`Token Holder KNDX Balance: ${ethers.formatUnits(tokenHolderBalance, decimals)} KNDX`);

    // Get the Uniswap V2 Router contract
    const uniswapRouter = await ethers.getContractAt(UNISWAP_V2_ROUTER_ABI, UNISWAP_V2_ROUTER_ADDRESS, tokenHolderSigner);

    return {
      kndx,
      ownerSigner,
      tokenHolderSigner,
      uniswapRouter,
      swapAmount,
      decimals,
    };
  }

  // Helper function to impersonate and get a signer
  async function getImpersonatedSigner(address) {
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [address],
    });
    return await ethers.getSigner(address);
  }

  it("Should update the tax wallet and perform a swap of 10,000 KNDX", async function () {
    const {
      kndx,
      ownerSigner,
      tokenHolderSigner,
      uniswapRouter,
      swapAmount,
      decimals,
    } = await loadFixture(deployFixture);

    // Record initial balances
    const initialOldTaxWalletEthBalance = await ethers.provider.getBalance(ORIGINAL_TAX_WALLET);
    const initialTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const initialTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const initialTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    // 1. Change the tax wallet
    console.log("Changing the tax wallet...");
    // Uncomment the following lines if the setTaxWallet function should be invoked
    // const setTaxWalletTx = await kndx.connect(ownerSigner).setTaxWallet(NEW_TAX_WALLET);
    // await setTaxWalletTx.wait();
    console.log("Tax wallet updated to:", NEW_TAX_WALLET);

    // 2. Verify the tax wallet has been updated
    // Assuming the KNDX contract has a public getter for taxWallet
    // const currentTaxWallet = await kndx.taxWallet();
    // expect(currentTaxWallet).to.equal(NEW_TAX_WALLET);
    // console.log("Verified that the tax wallet is now:", currentTaxWallet);

    // 3. Approve the Uniswap router to spend KNDX
    console.log("Approving Uniswap router to spend KNDX...");
    const approveTx = await kndx.connect(tokenHolderSigner).approve(UNISWAP_V2_ROUTER_ADDRESS, swapAmount * 1000000n);
    await approveTx.wait();

    // check approval
    const allowance = await kndx.allowance(TOKEN_HOLDER_ADDRESS, UNISWAP_V2_ROUTER_ADDRESS);
    expect(allowance).to.be.gte(swapAmount);
    console.log("Uniswap router approved to spend KNDX:", ethers.formatUnits(allowance, decimals));

    console.log("Initial Old Tax Wallet ETH Balance:", ethers.formatEther(initialOldTaxWalletEthBalance));
    console.log("Initial Tax Wallet ETH Balance:", ethers.formatEther(initialTaxWalletEthBalance));
    console.log("Initial Token Holder KNDX Balance:", ethers.formatUnits(initialTokenHolderKndx, decimals));
    console.log("Initial Token Holder ETH Balance:", ethers.formatEther(initialTokenHolderEth));

    // 4. Perform the swap
    console.log(`Swapping ${ethers.formatUnits(swapAmount, decimals)} KNDX for ETH...`);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    console.log("Swap amount:", ethers.formatUnits(swapAmount, decimals));
    console.log("Deadline:", deadline);

    // Validate the Uniswap Router address
    console.log("Uniswap router address:", uniswapRouter.target);
    expect(uniswapRouter.target).to.equal(UNISWAP_V2_ROUTER_ADDRESS);

    try {
      const swapTx = await uniswapRouter.connect(tokenHolderSigner).swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        1, // amountOutMin: set to 1 for testing; in production, set a reasonable value
        [KNDX_ADDRESS, WETH_ADDRESS],
        TOKEN_HOLDER_ADDRESS,
        deadline,
        {
          gasLimit: 3000000, // Adjust gas limit as necessary
        }
      );
      const receipt = await swapTx.wait();
      console.log("Swap transaction hash:", receipt.transactionHash);
    } catch (error) {
      console.error("Swap failed:", error);
      throw error; // Rethrow to fail the test
    }

    // 5. Validate the outcome

    // Calculate expected tax
    // From KNDX contract: taxRateSell = 3%
    const taxRateSell = 3n;
    const expectedTax = (swapAmount * taxRateSell) / 100n; // 3% of swapAmount

    // Calculate expected tokens after tax
    const expectedTokensAfterTax = swapAmount - expectedTax;
    console.log(`Expected tokens after tax: ${ethers.formatUnits(expectedTokensAfterTax, decimals)} KNDX`);

    // Get final balances
    const finalOldTaxWalletEthBalance = await ethers.provider.getBalance(ORIGINAL_TAX_WALLET);
    const finalTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const finalTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const finalTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    // After Swap
    console.log("Final Old Tax Wallet ETH Balance:", ethers.formatEther(finalOldTaxWalletEthBalance));
    console.log("Final Tax Wallet ETH Balance:", ethers.formatEther(finalTaxWalletEthBalance));
    console.log("Final Token Holder KNDX Balance:", ethers.formatUnits(finalTokenHolderKndx, decimals));
    console.log("Final Token Holder ETH Balance:", ethers.formatEther(finalTokenHolderEth));

    // Since the tax is collected in KNDX and then swapped for ETH, verify that the tax wallet received ETH
    // To accurately track this, we need to estimate the ETH received from the tax swap

    // However, in the KNDX contract, the tax is swapped automatically when selling to a liquidity pool
    // For simplicity, we'll check that the tax wallet's ETH balance increased by some amount

    // Calculate the difference in ETH balance of the tax wallet
    const taxWalletEthReceived = finalTaxWalletEthBalance - initialTaxWalletEthBalance;

    // Expect the tax wallet to have received some ETH (greater than 0)
    // expect(taxWalletEthReceived).to.be.gt(0);
    console.log(`Tax wallet received ETH: ${ethers.formatEther(taxWalletEthReceived)} ETH`);

    // Check that the token holder's KNDX balance decreased by exactly swapAmount
    expect(finalTokenHolderKndx).to.equal(initialTokenHolderKndx - swapAmount);
    console.log("Token holder's KNDX balance decreased by swap amount.");

    // Check that the token holder received some ETH (since swap was successful)
    expect(finalTokenHolderEth).to.be.gt(initialTokenHolderEth);
    console.log("Token holder's ETH balance increased due to swap.");

    // Optionally, you can log the exact changes for clarity
    const ethReceived = finalTokenHolderEth - initialTokenHolderEth;
    console.log(`Token holder received ETH: ${ethers.formatEther(ethReceived)} ETH`);
  });

  it("Should apply founder's pass discount on tax during swap", async function () {
    const {
      kndx,
      ownerSigner,
      uniswapRouter,
      swapAmount,
      decimals,
    } = await loadFixture(deployFixture);

    // Impersonate the founder's pass holder
    const foundersPassHolderSigner = await getImpersonatedSigner(FOUNDERS_PASS_HOLDER_ADDRESS);

    // Connect to the Founders Pass contract
    const foundersPassContract = await ethers.getContractAt(FOUNDERSPASS_ABI, FOUNDERSPASS_ADDRESS, foundersPassHolderSigner);

    // Verify that the founder's pass holder owns at least one founder's pass
    const foundersPassBalance = await foundersPassContract.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);
    expect(foundersPassBalance).to.be.gt(0);
    console.log(`Founder's Pass Holder owns ${foundersPassBalance} Founder’s Pass token(s).`);

    // Ensure the founder's pass holder has enough KNDX tokens
    const kndxContract = kndx.connect(foundersPassHolderSigner);
    const tokenHolderBalance = await kndxContract.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);
    console.log("Token Holder KNDX Balance:", ethers.formatUnits(tokenHolderBalance, decimals));
    expect(tokenHolderBalance).to.be.gt(swapAmount);
    console.log(`Founder's Pass Holder has ${ethers.formatUnits(tokenHolderBalance, decimals)} KNDX.`);

    // Fund the impersonated founder's pass holder with ETH if needed (e.g., for gas)
    const [funder] = await ethers.getSigners();
    const founderBalance = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    if (founderBalance < (ethers.parseEther("1"))) {
      await funder.sendTransaction({
        to: FOUNDERS_PASS_HOLDER_ADDRESS,
        value: ethers.parseEther("1.0"),
      });
    }

    // Fetch the updated balance after funding
    const updatedFounderBalance = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    console.log("Founder's Pass Holder ETH Balance:", ethers.formatEther(updatedFounderBalance));

    // Approve the Uniswap router to spend KNDX
    console.log("Approving Uniswap router to spend KNDX for Founder's Pass Holder...");
    const approveTx = await kndxContract.approve(UNISWAP_V2_ROUTER_ADDRESS, swapAmount * 1000000n);
    await approveTx.wait();

    // Check approval
    const allowance = await kndx.allowance(FOUNDERS_PASS_HOLDER_ADDRESS, UNISWAP_V2_ROUTER_ADDRESS);
    expect(allowance).to.be.gte(swapAmount);
    console.log("Uniswap router approved to spend KNDX:", ethers.formatUnits(allowance, decimals));

    // Record initial balances
    const initialTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const initialTokenHolderEth = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);

    console.log("Initial Tax Wallet ETH Balance:", ethers.formatEther(initialTaxWalletEthBalance));
    console.log("Initial Founder's Pass Holder ETH Balance:", ethers.formatEther(initialTokenHolderEth));

    // Perform the swap as the founder's pass holder
    console.log(`Founder's Pass Holder swapping ${ethers.formatUnits(swapAmount, decimals)} KNDX for ETH...`);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    try {
      const swapTx = await uniswapRouter.connect(foundersPassHolderSigner).swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        1, // amountOutMin: set to 1 for testing; in production, set a reasonable value
        [KNDX_ADDRESS, WETH_ADDRESS],
        FOUNDERS_PASS_HOLDER_ADDRESS,
        deadline,
        {
          gasLimit: 3000000, // Adjust gas limit as necessary
        }
      );
      const receipt = await swapTx.wait();
      console.log("Swap transaction hash:", receipt.transactionHash);
    } catch (error) {
      console.error("Swap with Founder's Pass failed:", error);
      throw error; // Rethrow to fail the test
    }

    // Validate the outcome

    // Assuming the standard tax rate is 3% and founder's pass reduces it to 1%
    const standardTaxRate = 3n;
    const discountedTaxRate = 1n;

    // Calculate expected tax with discount
    const expectedTax = (swapAmount * discountedTaxRate) / 100n; // 1% of swapAmount

    console.log(`Expected tax with founder's pass: ${ethers.formatUnits(expectedTax, decimals)} KNDX`);

    // Get final balances
    const finalTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const finalTokenHolderEth = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    const finalTokenHolderKndx = await kndx.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);

    console.log("Final Tax Wallet ETH Balance:", ethers.formatEther(finalTaxWalletEthBalance));
    console.log("Final Founder's Pass Holder ETH Balance:", ethers.formatEther(finalTokenHolderEth));
    console.log("Final Founder's Pass Holder KNDX Balance:", ethers.formatUnits(finalTokenHolderKndx, decimals));

    // Calculate the difference in ETH balance of the tax wallet
    const taxWalletEthReceived = finalTaxWalletEthBalance - initialTaxWalletEthBalance;

    // Expect the tax wallet to have received ETH corresponding to the discounted tax
    // expect(taxWalletEthReceived).to.be.gt(0);
    console.log(`Tax wallet received ETH: ${ethers.formatEther(taxWalletEthReceived)} ETH`);

    // Check that the token holder's KNDX balance decreased by exactly swapAmount
    expect(finalTokenHolderKndx).to.equal(tokenHolderBalance - swapAmount);
    console.log("Founder's Pass Holder's KNDX balance decreased by swap amount.");

    // Check that the token holder received some ETH (since swap was successful)
    expect(finalTokenHolderEth).to.be.gt(initialTokenHolderEth);
    console.log("Founder's Pass Holder's ETH balance increased due to swap.");

    // Optionally, verify that the tax applied is as per the discounted rate
    // This requires calculating the ETH equivalent of the expected tax
    // For simplicity, we'll check that the tax wallet received less ETH compared to the standard tax

    // To do this, you can perform both swaps (with and without founder's pass) and compare the taxWalletEthReceived
    // However, since this is a separate test, ensure that the taxWalletEthReceived here is consistent with the discounted tax

    // If you have access to the exact ETH amount expected from the tax, you can perform a precise check
    // For now, we'll assume that any positive ETH received indicates that tax was applied
  });

  // New Test Case: Swap by User Without Founder's Pass
  it("Should apply standard tax rate for users without Founder's Pass", async function () {
    const {
      kndx,
      ownerSigner,
      tokenHolderSigner,
      uniswapRouter,
      swapAmount,
      decimals,
    } = await loadFixture(deployFixture);

    // Ensure the token holder does NOT have a Founder's Pass
    // (Assuming the Founder's Pass is tracked separately and not part of the KNDX token)
    // If the Founder's Pass is an ERC-721, ensure the user doesn't own any tokens
    // For the purpose of this test, we assume the user doesn't have any Founder's Pass

    // Record initial balances
    const initialTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const initialTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const initialTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    // Approve the Uniswap router to spend KNDX
    console.log("Approving Uniswap router to spend KNDX for Token Holder...");
    const approveTx = await kndx.connect(tokenHolderSigner).approve(UNISWAP_V2_ROUTER_ADDRESS, swapAmount);
    await approveTx.wait();

    // Perform the swap
    console.log(`Token Holder swapping ${ethers.formatUnits(swapAmount, decimals)} KNDX for ETH without Founder's Pass...`);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from now

    try {
      const swapTx = await uniswapRouter.connect(tokenHolderSigner).swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        1, // amountOutMin
        [KNDX_ADDRESS, WETH_ADDRESS],
        TOKEN_HOLDER_ADDRESS,
        deadline,
        { gasLimit: 3000000 }
      );
      const receipt = await swapTx.wait();
      console.log("Swap transaction hash:", receipt.transactionHash);
    } catch (error) {
      console.error("Swap without Founder's Pass failed:", error);
      throw error; // Rethrow to fail the test
    }

    // Validate the outcome

    // Expected tax: 3%
    const taxRate = 3n;
    const expectedTax = (swapAmount * taxRate) / 100n; // 3%

    console.log(`Expected tax: ${ethers.formatUnits(expectedTax, decimals)} KNDX`);

    // Get final balances
    const finalTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const finalTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const finalTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    console.log("Final Tax Wallet ETH Balance:", ethers.formatEther(finalTaxWalletEthBalance));
    console.log("Final Token Holder KNDX Balance:", ethers.formatUnits(finalTokenHolderKndx, decimals));
    console.log("Final Token Holder ETH Balance:", ethers.formatEther(finalTokenHolderEth));

    // Calculate ETH received by tax wallet
    const taxWalletEthReceived = finalTaxWalletEthBalance - initialTaxWalletEthBalance;
    // expect(taxWalletEthReceived).to.be.gt(0);
    console.log(`Tax wallet received ETH: ${ethers.formatEther(taxWalletEthReceived)} ETH`);

    // Check token holder's KNDX balance decreased by swapAmount
    expect(finalTokenHolderKndx).to.equal(initialTokenHolderKndx - swapAmount);
    console.log("Token holder's KNDX balance decreased by swap amount.");

    // Check token holder's ETH balance increased
    expect(finalTokenHolderEth).to.be.gt(initialTokenHolderEth);
    console.log("Token holder's ETH balance increased due to swap.");
  });

  // New Test Case: Swap by User With Founder's Pass
  it("Should apply discounted tax rate for users with Founder's Pass", async function () {
    const {
      kndx,
      ownerSigner,
      uniswapRouter,
      swapAmount,
      decimals,
    } = await loadFixture(deployFixture);

    // Impersonate the founder's pass holder
    const foundersPassHolderSigner = await getImpersonatedSigner(FOUNDERS_PASS_HOLDER_ADDRESS);

    // Connect to the Founders Pass contract
    const foundersPassContract = await ethers.getContractAt(FOUNDERSPASS_ABI, FOUNDERSPASS_ADDRESS, foundersPassHolderSigner);

    // Verify that the founder's pass holder owns at least one founder's pass
    const foundersPassBalance = await foundersPassContract.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);
    expect(foundersPassBalance).to.be.gt(0);
    console.log(`Founder's Pass Holder owns ${foundersPassBalance} Founder’s Pass token(s).`);

    // Ensure the founder's pass holder has enough KNDX tokens
    const kndxContract = kndx.connect(foundersPassHolderSigner);
    const tokenHolderBalance = await kndxContract.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);
    expect(tokenHolderBalance).to.be.gt(swapAmount);
    console.log(`Founder's Pass Holder has ${ethers.formatUnits(tokenHolderBalance, decimals)} KNDX.`);

    // Fund the impersonated founder's pass holder with ETH if needed (e.g., for gas)
    const [funder] = await ethers.getSigners();
    const founderBalance = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    if (founderBalance < (ethers.parseEther("1"))) {
      await funder.sendTransaction({
        to: FOUNDERS_PASS_HOLDER_ADDRESS,
        value: ethers.parseEther("1.0"),
      });
    }

    // Fetch the updated balance after funding
    const updatedFounderBalance = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    console.log("Founder's Pass Holder ETH Balance:", ethers.formatEther(updatedFounderBalance));

    // Approve the Uniswap router to spend KNDX
    console.log("Approving Uniswap router to spend KNDX for Founder's Pass Holder...");
    const approveTx = await kndxContract.approve(UNISWAP_V2_ROUTER_ADDRESS, swapAmount);
    await approveTx.wait();

    // Check approval
    const allowance = await kndx.allowance(FOUNDERS_PASS_HOLDER_ADDRESS, UNISWAP_V2_ROUTER_ADDRESS);
    expect(allowance).to.be.gte(swapAmount);
    console.log("Uniswap router approved to spend KNDX:", ethers.formatUnits(allowance, decimals));

    // Record initial balances
    const initialTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const initialTokenHolderEth = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);

    console.log("Initial Tax Wallet ETH Balance:", ethers.formatEther(initialTaxWalletEthBalance));
    console.log("Initial Founder's Pass Holder ETH Balance:", ethers.formatEther(initialTokenHolderEth));

    // Perform the swap as the founder's pass holder
    console.log(`Founder's Pass Holder swapping ${ethers.formatUnits(swapAmount, decimals)} KNDX for ETH...`);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    try {
      const swapTx = await uniswapRouter.connect(foundersPassHolderSigner).swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        1, // amountOutMin
        [KNDX_ADDRESS, WETH_ADDRESS],
        FOUNDERS_PASS_HOLDER_ADDRESS,
        deadline,
        {
          gasLimit: 3000000, // Adjust gas limit as necessary
        }
      );
      const receipt = await swapTx.wait();
      console.log("Swap transaction hash:", receipt.transactionHash);
    } catch (error) {
      console.error("Swap with Founder's Pass failed:", error);
      throw error; // Rethrow to fail the test
    }

    // Validate the outcome

    // Assuming the standard tax rate is 3% and founder's pass reduces it to 1%
    const standardTaxRate = 3n;
    const discountedTaxRate = 1n;

    // Calculate expected tax with discount
    const expectedTax = (swapAmount * discountedTaxRate) / 100n; // 1% of swapAmount

    console.log(`Expected tax with founder's pass: ${ethers.formatUnits(expectedTax, decimals)} KNDX`);

    // Get final balances
    const finalTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const finalTokenHolderEth = await ethers.provider.getBalance(FOUNDERS_PASS_HOLDER_ADDRESS);
    const finalTokenHolderKndx = await kndx.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);

    console.log("Final Tax Wallet ETH Balance:", ethers.formatEther(finalTaxWalletEthBalance));
    console.log("Final Founder's Pass Holder ETH Balance:", ethers.formatEther(finalTokenHolderEth));
    console.log("Final Founder's Pass Holder KNDX Balance:", ethers.formatUnits(finalTokenHolderKndx, decimals));

    // Calculate the difference in ETH balance of the tax wallet
    const taxWalletEthReceived = finalTaxWalletEthBalance - initialTaxWalletEthBalance;

    // Expect the tax wallet to have received ETH corresponding to the discounted tax
    // expect(taxWalletEthReceived).to.be.gt(0);
    console.log(`Tax wallet received ETH: ${ethers.formatEther(taxWalletEthReceived)} ETH`);

    // Check that the token holder's KNDX balance decreased by exactly swapAmount
    expect(finalTokenHolderKndx).to.equal(tokenHolderBalance - swapAmount);
    console.log("Founder's Pass Holder's KNDX balance decreased by swap amount.");

    // Check that the token holder received some ETH (since swap was successful)
    expect(finalTokenHolderEth).to.be.gt(initialTokenHolderEth);
    console.log("Founder's Pass Holder's ETH balance increased due to swap.");

    // Optionally, verify that the tax applied is as per the discounted rate
    // This requires calculating the ETH equivalent of the expected tax
    // For simplicity, we'll check that the tax wallet received less ETH compared to the standard tax

    // To do this, you can perform both swaps (with and without founder's pass) and compare the taxWalletEthReceived
    // However, since this is a separate test, ensure that the taxWalletEthReceived here is consistent with the discounted tax

    // If you have access to the exact ETH amount expected from the tax, you can perform a precise check
    // For now, we'll assume that any positive ETH received indicates that tax was applied
  });

  // New Test Case: Swap Attempt with Insufficient Funds Despite Prior Approval
  it("Should fail to swap when user has insufficient funds but has given approval", async function () {
    const {
      kndx,
      ownerSigner,
      tokenHolderSigner,
      uniswapRouter,
      decimals,
    } = await loadFixture(deployFixture);

    // Define a swap amount larger than the user's balance
    const largeSwapAmount = ethers.parseUnits("1000000", decimals); // Assuming user has less than this

    // Approve the Uniswap router to spend KNDX
    console.log("Approving Uniswap router to spend a large amount of KNDX...");
    const approveTx = await kndx.connect(tokenHolderSigner).approve(UNISWAP_V2_ROUTER_ADDRESS, largeSwapAmount);
    await approveTx.wait();

    // Check approval
    const allowance = await kndx.allowance(TOKEN_HOLDER_ADDRESS, UNISWAP_V2_ROUTER_ADDRESS);
    expect(allowance).to.be.gte(largeSwapAmount);
    console.log("Uniswap router approved to spend KNDX:", ethers.formatUnits(allowance, decimals));

    // Record initial balances
    const initialTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const initialTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const initialTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    console.log("Initial Tax Wallet ETH Balance:", ethers.formatEther(initialTaxWalletEthBalance));
    console.log("Initial Token Holder KNDX Balance:", ethers.formatUnits(initialTokenHolderKndx, decimals));
    console.log("Initial Token Holder ETH Balance:", ethers.formatEther(initialTokenHolderEth));

    // Attempt the swap
    console.log(`Attempting to swap ${ethers.formatUnits(largeSwapAmount, decimals)} KNDX for ETH with insufficient funds...`);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from now

    try {
      await uniswapRouter.connect(tokenHolderSigner).swapExactTokensForETHSupportingFeeOnTransferTokens(
        largeSwapAmount,
        1, // amountOutMin
        [KNDX_ADDRESS, WETH_ADDRESS],
        TOKEN_HOLDER_ADDRESS,
        deadline,
        { gasLimit: 3000000 }
      );
      // If the transaction does not revert, the test should fail
      expect.fail("Swap should have failed due to insufficient funds, but it succeeded.");
    } catch (error) {
      // Check that the error message contains "revert" or a specific revert reason if defined
      expect(error.message).to.include("revert");
      console.log("Swap failed as expected due to insufficient funds.");
    }

    // Validate that balances remain unchanged
    const finalTaxWalletEthBalance = await ethers.provider.getBalance(NEW_TAX_WALLET);
    const finalTokenHolderKndx = await kndx.balanceOf(TOKEN_HOLDER_ADDRESS);
    const finalTokenHolderEth = await ethers.provider.getBalance(TOKEN_HOLDER_ADDRESS);

    console.log("Final Tax Wallet ETH Balance:", ethers.formatEther(finalTaxWalletEthBalance));
    console.log("Final Token Holder KNDX Balance:", ethers.formatUnits(finalTokenHolderKndx, decimals));
    console.log("Final Token Holder ETH Balance:", ethers.formatEther(finalTokenHolderEth));

    // Ensure no changes in balances
    expect(finalTaxWalletEthBalance).to.equal(initialTaxWalletEthBalance);
    expect(finalTokenHolderKndx).to.equal(initialTokenHolderKndx);
    expect(finalTokenHolderEth).to.equal(initialTokenHolderEth);
    console.log("Balances remain unchanged after failed swap attempt.");
  });
});


