const { ethers } = require("hardhat");
require("dotenv").config();

/*
 * Deployment script for KonduxBatchMinter
 *
 * This script deploys the KonduxBatchMinter contract along with the
 * minimal dependencies required for it to function. It supports three
 * deployment targets:
 *   1. Local: deploys MockKondux and MockAuthority, then KonduxBatchMinter.
 *   2. Sepolia: reuses pre‑deployed Kondux addresses and deploys a
 *      MockAuthority pointing at the existing treasury address.
 *   3. Mainnet: reuses existing Kondux and treasury addresses and
 *      deploys a MockAuthority pointing at the treasury.
 *
 * Usage:
 *   npx hardhat run deployBatchMinter.js
 *   npx hardhat run deployBatchMinter.js --network sepolia
 *   npx hardhat run deployBatchMinter.js --network mainnet
 *
 * If a network flag is not supplied the script will deploy to the
 * default Hardhat network (usually an in‑memory local chain). When
 * deploying to Sepolia or Mainnet the script expects appropriate
 * private keys to be provided via environment variables as described
 * below.
 */

// Addresses for the existing Kondux contracts and other dependencies on
// the different networks. These values are taken from the user's
// deployment configuration and can be updated as needed.
const MAINNET_ADDRESSES = {
  ADMIN_ADDRESS: "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
  KNFT_ADDRESS: "0x5aD180dF8619CE4f888190C3a926111a723632ce",
  TREASURY_ADDRESS: "0x15Eb71031430C08946E6733a16498F7397Ad13b3",
  FOUNDERSPASS_ADDRESS: "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
  PAYMENT_TOKEN_ADDRESS: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
  UNISWAP_PAIR_ADDRESS: "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
  WETH_ADDRESS: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  UNISWAP_V2_ROUTER_ADDRESS: "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
  AVATAR_ADDRESS: "0xb885880f5e4Ad1064e02f56beb5175BA9801fC96",
  AUTHORITY_ADDRESS: "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A"
};

const PREDEPLOYED_ADDRESSES = {
  // Addresses of contracts already deployed on Sepolia/Goerli.
  KNFT_ADDRESS: "0xDDAEc4bfe0D64A234F49F2fe1d22c42126089Ac1",
  TREASURY_ADDRESS: "0x17719306030fE5fBf6094fb0e2A38D948dDAfd0c",
  FOUNDERSPASS_ADDRESS: "0xBE983455A9FF94480510Be64Ee4df75F444638AF",
  PAYMENT_TOKEN_ADDRESS: "0x7601584C416aFC4DB0299964ceBD0aD2C7Da2500",
  UNISWAP_PAIR_ADDRESS: "0xD5714c7dE4297199F08B0c7250DecFd3a4902718",
  AUTHORITY_ADDRESS: "0xfF0b8218353F088173779B0079263F672Aa3B548"
};

/**
 * Helper: determine which signer to use based on the current network.
 *
 * When deploying to remote networks you should supply a private key via
 * environment variables. For Sepolia the script uses DEPLOYER_PK; for
 * Mainnet it prefers PROD_DEPLOYER_PK if defined and falls back to
 * DEPLOYER_PK. When running on a local Hardhat network the default
 * signer exposed by ethers.provider.getSigner() is used.
 *
 * @param {string} targetNetwork The target network name.
 * @returns {Promise<Signer>} A signer connected to the current provider.
 */
async function getSigner(targetNetwork) {
  if (targetNetwork === "mainnet") {
    const pk = process.env.PROD_DEPLOYER_PK || process.env.DEPLOYER_PK;
    if (!pk) {
      throw new Error(
        "Missing PROD_DEPLOYER_PK or DEPLOYER_PK environment variable for mainnet deployment"
      );
    }
    return new ethers.Wallet(pk, ethers.provider);
  } else if (targetNetwork === "sepolia" || targetNetwork === "goerli") {
    const pk = process.env.DEPLOYER_PK;
    if (!pk) {
      throw new Error(
        "Missing DEPLOYER_PK environment variable for testnet deployment"
      );
    }
    return new ethers.Wallet(pk, ethers.provider);
  }
  // Default: local hardhat signer
  const accounts = await ethers.getSigners();
  return accounts[0];
}

async function main() {
  // Determine the network selected via Hardhat; fallback to 'localhost' for in‑memory network
  const hreNetwork = await ethers.provider.getNetwork();
  let targetNetwork = hreNetwork.name; // e.g. 'homestead', 'sepolia', 'goerli', 'hardhat'
  // Normalize network names
  if (targetNetwork === "homestead") targetNetwork = "mainnet";
  if (targetNetwork === "hardhat" || targetNetwork === "localhost") targetNetwork = "localhost";

  console.log(`\nDeploying KonduxBatchMinter on network: ${targetNetwork}\n`);

  const signer = await getSigner(targetNetwork);
  console.log(`Signer address: ${await signer.getAddress()}`);
  console.log(
    `Signer balance: ${ethers.formatEther(await ethers.provider.getBalance(await signer.getAddress()))} ETH`
  );

  let konduxAddress;
  let vaultAddress;
  let authorityAddress;

  // For local deployments we need to deploy a mock Kondux NFT contract
  if (targetNetwork === "localhost") {
    console.log("Deploying MockKondux and MockAuthority for local network...");
    // Deploy MockKondux
    const MockKonduxFactory = await ethers.getContractFactory("MockKondux");
    const mockKondux = await MockKonduxFactory.connect(signer).deploy();
    await mockKondux.waitForDeployment();
    konduxAddress = mockKondux.target;
    console.log(`MockKondux deployed at: ${konduxAddress}`);

    // Use the signer's address as the vault (forwards ETH to deployer)
    vaultAddress = await signer.getAddress();
  } else if (targetNetwork === "sepolia" || targetNetwork === "goerli") {
    console.log("Using pre‑deployed addresses on the testnet...");
    konduxAddress = PREDEPLOYED_ADDRESSES.KNFT_ADDRESS;
    vaultAddress = PREDEPLOYED_ADDRESSES.TREASURY_ADDRESS;
  } else if (targetNetwork === "mainnet") {
    console.log("Using pre‑deployed addresses on mainnet...");
    // Use the AVATAR address as the Kondux NFT; adjust if a different contract is intended
    konduxAddress = MAINNET_ADDRESSES.AVATAR_ADDRESS || MAINNET_ADDRESSES.KNFT_ADDRESS;
    vaultAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
  } else {
    throw new Error(`Unsupported network: ${targetNetwork}`);
  }

  // Deploy a MockAuthority that returns the vault address. On local this will
  // forward funds back to the deployer; on remote networks it forwards to
  // the actual treasury contract.
  if (targetNetwork === "localhost") {
    console.log("Deploying MockAuthority...");
    const MockAuthorityFactory = await ethers.getContractFactory("MockAuthority");
    const authority = await MockAuthorityFactory.connect(signer).deploy(vaultAddress);
    await authority.waitForDeployment();
    authorityAddress = authority.target;
    console.log(`MockAuthority deployed at: ${authorityAddress}`);
  } else if (targetNetwork === "sepolia" || targetNetwork === "goerli") {
    authorityAddress = PREDEPLOYED_ADDRESSES.AUTHORITY_ADDRESS;
  } else if (targetNetwork === "mainnet") {
    authorityAddress = MAINNET_ADDRESSES.AUTHORITY_ADDRESS;
  }

  // Finally deploy KonduxBatchMinter
  console.log("Deploying KonduxBatchMinter...");
  const BatchMinterFactory = await ethers.getContractFactory("KonduxBatchMinter");
  const batchMinter = await BatchMinterFactory.connect(signer).deploy(
    konduxAddress,
    authorityAddress
  );
  await batchMinter.waitForDeployment();

  console.log(`KonduxBatchMinter deployed at: ${batchMinter.target}`);
  console.log("\nDeployment complete.\n");

  // Optional: provide useful Hardhat verify arguments for Etherscan
  console.log("Arguments for Etherscan verification for KonduxBatchMinter:");
  console.log(`${batchMinter.target} ${konduxAddress} ${authorityAddress}`);

  // ---------------------------------------------------------------------------
  // Grant the deployed KonduxBatchMinter the MINTER_ROLE on the kNFT contract.
  // This is necessary so that the batch minter can mint tokens on behalf of users.
  // ---------------------------------------------------------------------------
  try {
    // Define the MINTER_ROLE constant using the same hash as in the Kondux contract
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

    // Obtain the deployed kNFT contract instance. Replace "KonduxImplementation"
    // with the actual contract name if different in your project.
    const konduxContract = await ethers.getContractAt(
      "KonduxImplementation",
      konduxAddress
    );

    console.log(`Granting MINTER_ROLE to ${batchMinter.target} on kNFT...`);
    const grantTx = await konduxContract
      .connect(signer)
      .grantRole(MINTER_ROLE, batchMinter.target);

    await grantTx.wait();
    console.log("MINTER_ROLE granted successfully.");
  } catch (err) {
    console.warn(
      "Unable to grant MINTER_ROLE. Ensure the contract name matches the deployed kNFT and the signer has admin privileges."
    );
    console.error(err);
  }
}

// Execute the deployment function and handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
