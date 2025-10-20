const { ethers, network } = require("hardhat");
require("dotenv").config();

async function main() {
  const networkName = network.name;
  console.log(`\nStarting deployment on network: ${networkName}`);

  /**
   * Addresses for MAINNET or your production environment
   * Change these to your real Chainlink Functions Router address and any admin as needed.
   */
  const MAINNET_ADDRESSES = {
    CHAINLINK_FUNCTIONS_ROUTER: "0x65Dcc24F8ff9e51F10DCc7Ed1e4e2A61e6E14bd6",
  };

  /**
   * Addresses for TESTNET (Sepolia, Goerli, etc.)
   * Replace with the actual Chainlink Functions Router address for your testnet.
   */
  const TESTNET_ADDRESSES = {
    CHAINLINK_FUNCTIONS_ROUTER: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0", 
  };

  /**
   * If you have a predeployed or known router address on your testnets, store it here.
   * If `IS_PRE_DEPLOYED = true`, we’ll use it directly.
   */
  const PREDEPLOYED_ADDRESSES = {
    CHAINLINK_FUNCTIONS_ROUTER: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0", 
  };

  // Whether to use predeployed addresses on testnets or not
  const IS_PRE_DEPLOYED = true;

  // Decide which private key to use based on network
  let deployerPK = process.env.DEPLOYER_PK;
  if (networkName === "mainnet" || networkName === "hardhat") {
    deployerPK = process.env.PROD_DEPLOYER_PK;
  }

  // Instantiate signer
  const signer = new ethers.Wallet(deployerPK, ethers.provider);
  console.log(`Deployer Address: ${await signer.getAddress()}`);
  const deployerBalance = await ethers.provider.getBalance(await signer.getAddress());
  console.log(`Deployer Balance: ${ethers.formatEther(deployerBalance)} ETH\n`);

  let functionsRouterAddress;

  // Decide addresses based on the network
  if (networkName === "mainnet" || networkName === "hardhat") {
    console.log("Using Mainnet-like addresses.\n");
    functionsRouterAddress = MAINNET_ADDRESSES.CHAINLINK_FUNCTIONS_ROUTER;
  } else if (networkName === "sepolia" || networkName === "goerli") {
    console.log("Using testnet flow.\n");
    if (!IS_PRE_DEPLOYED) {
      /**
       * If you don't have a known Chainlink Functions Router address on testnet,
       * you might deploy or reference a local mock. However, typically you'll have
       * a real testnet router from Chainlink. This is just an example approach:
       */

      // Deploy a mock router if necessary
      // e.g. const MockRouter = await ethers.getContractFactory("MockFunctionsRouter");
      // const mockRouter = await MockRouter.connect(signer).deploy();
      // await mockRouter.waitForDeployment();
      // functionsRouterAddress = mockRouter.target;
      // console.log(`MockFunctionsRouter deployed to: ${functionsRouterAddress}`);

      // For demonstration, we’ll just throw, indicating you must set a real address:
      throw new Error("No testnet router address set and IS_PRE_DEPLOYED=false. Provide a real or mock router.");
    } else {
      // Use the predeployed router address
      functionsRouterAddress = PREDEPLOYED_ADDRESSES.CHAINLINK_FUNCTIONS_ROUTER;
    }
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  console.log("Final address used for Chainlink Functions Router:");
  console.log(`  ${functionsRouterAddress}\n`);

  /**
   * Now deploy KonduxOracle
   * 
   * constructor(address functionsRouter)
   *   FunctionsClient(functionsRouter)
   *   ConfirmedOwner(msg.sender)
   */
  console.log("Deploying KonduxOracle...");

  const KonduxOracle = await ethers.getContractFactory("KonduxOracle");
  console.log("Constructor argument:");
  console.log(`  functionsRouter: ${functionsRouterAddress}`);

  const konduxOracle = await KonduxOracle.connect(signer).deploy(functionsRouterAddress);
  await konduxOracle.waitForDeployment();
  console.log(`\nKonduxOracle deployed to: ${konduxOracle.target}`);

  // Arguments for Hardhat verify
  console.log("\nArguments for Hardhat verify:");
  console.log(`${functionsRouterAddress}`);

  console.log("\nDeployment completed successfully.\n");
}

// Execute the main script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
