const { ethers, network } = require("hardhat");
require("dotenv").config();

async function main() {
  const networkName = network.name;
  console.log(`\nStarting kNFTFactory deployment on network: ${networkName}`);

  // --------------------------------------------
  // Example existing addresses for different networks
  // (Adjust to your actual addresses or logic.)
  // --------------------------------------------
  const MAINNET_ADDRESSES = {
    AUTHORITY_ADDRESS: "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A", // Live authority
  };

  const TESTNET_ADDRESSES = {
    AUTHORITY_ADDRESS: "0xfF0b8218353F088173779B0079263F672Aa3B548", // Testnet Authority
  };

  let authorityAddress;

  if (networkName === "mainnet" || networkName === "hardhat") {
    console.log("Using Mainnet/Hardhat addresses...");
    authorityAddress = MAINNET_ADDRESSES.AUTHORITY_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli") {
    console.log("Using Testnet addresses...");
    authorityAddress = TESTNET_ADDRESSES.AUTHORITY_ADDRESS;
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  // --------------------------------------------
  // Private key logic
  // (we assume you have DEPLOYER_PK in .env for testnets, PROD_DEPLOYER_PK for mainnet)
  // --------------------------------------------
  let deployerPK = process.env.DEPLOYER_PK;
  if (networkName === "mainnet") {
    deployerPK = process.env.PROD_DEPLOYER_PK;
  }

  // Instantiate the signer
  if (!deployerPK) {
    throw new Error("No private key found in .env (DEPLOYER_PK or PROD_DEPLOYER_PK).");
  }

  const signer = new ethers.Wallet(deployerPK, ethers.provider);

  console.log(`Deployer Address: ${await signer.getAddress()}`);
  const balance = await ethers.provider.getBalance(await signer.getAddress());
  console.log(`Deployer Balance: ${ethers.formatEther(balance)} ETH`);

  // --------------------------------------------
  // Deploy kNFTFactory
  // --------------------------------------------
  console.log("\nDeploying kNFTFactory...");
  console.log(`Using Authority at: ${authorityAddress}`);

  const kNFTFactoryFactory = await ethers.getContractFactory("kNFTFactory", signer);
  const factoryContract = await kNFTFactoryFactory.deploy(authorityAddress);
  await factoryContract.waitForDeployment();

  const factoryAddress = await factoryContract.getAddress();
  console.log(`kNFTFactory deployed to: ${factoryAddress}`);

  // (Optional) If you want to do additional config after deploy,
  // e.g., setFeeEnabled, setFactoryActive, or grant roles, you can do it here:
  // await factoryContract.setFeeEnabled(true);
  // await factoryContract.setCreationFee(ethers.parseEther("0.01"));

  console.log("\nDeployment completed successfully.\n");
  console.log("You can verify with:");
  console.log(`npx hardhat verify --network ${networkName} ${factoryAddress} ${authorityAddress}\n`);
}

// Execute the main function and handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
