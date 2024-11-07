// scripts/ignitionDeploy.js
const { ethers, network } = require("hardhat");
require("dotenv").config();

async function main() {
  const networkName = network.name;
  console.log(`\nStarting deployment on network: ${networkName}`);

  // Define mainnet addresses
  const MAINNET_ADDRESSES = {
    ADMIN_ADDRESS: "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
    KNFT_ADDRESS: "0x5aD180dF8619CE4f888190C3a926111a723632ce",
    TREASURY_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
    FOUNDERSPASS_ADDRESS: "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
    PAYMENT_TOKEN_ADDRESS: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
    UNISWAP_PAIR_ADDRESS: "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
    WETH_ADDRESS: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    UNISWAP_V2_ROUTER_ADDRESS: "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
  };

  // Define testnet addresses
  const TESTNET_ADDRESSES = {
    WETH_ADDRESS: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    UNISWAP_V2_ROUTER_ADDRESS: "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008",
  };

  let kNFTAddress,
    foundersPassAddress,
    treasuryAddress,
    paymentTokenAddress,
    uniswapPairAddress,
    WETHAddress,
    UNISWAP_V2_ROUTER_ADDRESS;

  if (networkName === "mainnet") {
    console.log("Using Mainnet existing contract addresses.");

    kNFTAddress = MAINNET_ADDRESSES.KNFT_ADDRESS;
    foundersPassAddress = MAINNET_ADDRESSES.FOUNDERSPASS_ADDRESS;
    treasuryAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = MAINNET_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    uniswapPairAddress = MAINNET_ADDRESSES.UNISWAP_PAIR_ADDRESS;
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli" || networkName === "hardhat") {
    console.log("Deploying mock contracts for Testnet.");

    // Deploy MockKondux
    const MockKondux = await ethers.getContractFactory("MockKondux");
    const mockKondux = await MockKondux.deploy();
    await mockKondux.waitForDeployment();
    kNFTAddress = mockKondux.target;
    console.log(`MockKondux deployed to: ${kNFTAddress}`);

    // Deploy MockFoundersPass
    const MockFoundersPass = await ethers.getContractFactory("MockFoundersPass");
    const mockFoundersPass = await MockFoundersPass.deploy();
    await mockFoundersPass.waitForDeployment();
    foundersPassAddress = mockFoundersPass.target;
    console.log(`MockFoundersPass deployed to: ${foundersPassAddress}`);

    // Deploy MockTreasury
    const MockTreasury = await ethers.getContractFactory("MockTreasury");
    const mockTreasury = await MockTreasury.deploy();
    await mockTreasury.waitForDeployment();
    treasuryAddress = mockTreasury.target;
    console.log(`MockTreasury deployed to: ${treasuryAddress}`);

    // Deploy MockKonduxERC20
    const MockKonduxERC20 = await ethers.getContractFactory("MockKonduxERC20");
    const mockPaymentToken = await MockKonduxERC20.deploy();
    await mockPaymentToken.waitForDeployment();
    paymentTokenAddress = mockPaymentToken.target;
    console.log(`MockKonduxERC20 deployed to: ${paymentTokenAddress}`);

    // Use predefined Testnet Uniswap V2 Router address
    uniswapPairAddress = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
    console.log(`Using Testnet UniswapV2 Router Address: ${uniswapPairAddress}`);
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  // Define WETH and Uniswap V2 Router addresses based on network
  if (networkName === "mainnet") {
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli" || networkName === "hardhat") {
    WETHAddress = TESTNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  }
  console.log(`WETH Address: ${WETHAddress}`);
  console.log(`Uniswap V2 Router Address: ${UNISWAP_V2_ROUTER_ADDRESS}`);

  // Deploy KonduxTokenBasedMinter
  console.log("Deploying KonduxTokenBasedMinter...");
  const KonduxTokenBasedMinter = await ethers.getContractFactory("KonduxTokenBasedMinter");
  const konduxTokenBasedMinter = await KonduxTokenBasedMinter.deploy(
    kNFTAddress,
    foundersPassAddress,
    treasuryAddress,
    paymentTokenAddress,
    uniswapPairAddress,
    WETHAddress
  );
  await konduxTokenBasedMinter.waitForDeployment();
  console.log(`KonduxTokenBasedMinter deployed to: ${konduxTokenBasedMinter.target}`);

  // Grant MINTER_ROLE to KonduxTokenBasedMinter on the Kondux NFT contract
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  console.log(`Granting MINTER_ROLE to KonduxTokenBasedMinter on Kondux NFT contract.`, MINTER_ROLE);

  if (networkName === "mainnet") {
    const kNFTContract = await ethers.getContractAt("Kondux", kNFTAddress);
    const grantTx = await kNFTContract.grantRole(MINTER_ROLE, konduxTokenBasedMinter.target);
    await grantTx.wait();
    console.log(`Granted MINTER_ROLE to KonduxTokenBasedMinter on Kondux NFT contract.`);
  } else if (networkName === "sepolia" || networkName === "goerli" || networkName === "hardhat") {
    const mockKondux = await ethers.getContractAt("MockKondux", kNFTAddress);
    const grantTx = await mockKondux.grantRole(MINTER_ROLE, konduxTokenBasedMinter.target);
    await grantTx.wait();
    console.log(`Granted MINTER_ROLE to KonduxTokenBasedMinter on MockKondux NFT contract.`);
  }

  console.log("Deployment completed successfully.\n");
}

// Execute the main function and handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
