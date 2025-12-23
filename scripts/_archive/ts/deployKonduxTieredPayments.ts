const { ethers, network } = require("hardhat");
require("dotenv").config();

async function main() {
  const networkName = network.name;
  console.log(`\nStarting deployment on network: ${networkName}`);

  /**
   * Example mainnet addresses — placeholders
   * Replace with your actual production addresses.
   */
  const MAINNET_ADDRESSES = {
    ADMIN_ADDRESS: "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2", // Governor or admin
    TREASURY_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
    PAYMENT_TOKEN_ADDRESS: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
    KONDUX_ROYALTY_ADDRESS: "0x1234567890123456789012345678901234567890", // Kondux royalty recipient
  };

  /**
   * Example testnet addresses — placeholders
   * Typically for Goerli, Sepolia, etc.
   */
  const TESTNET_ADDRESSES = {
    // Just placeholders if you want separate known addresses
    // e.g., some existing testnet treasury, token, or royalty address
  };

  /**
   * If you have pre-deployed addresses on testnet that you want to reuse,
   * store them here. Otherwise you can deploy new mocks each time.
   */
  const PREDEPLOYED_ADDRESSES = {
    TREASURY_ADDRESS: "0x57B2FF8afF3b8A3307E2aE7bf0854167922aCf96",
    PAYMENT_TOKEN_ADDRESS: "0x7601584C416aFC4DB0299964ceBD0aD2C7Da2500",
    KONDUX_ROYALTY_ADDRESS: "0xBE983455A9FF94480510Be64Ee4df75F444638AF",
  };

  // Controls whether to use predeployed addresses or deploy new mocks on testnets
  const IS_PRE_DEPLOYED = true;

  // Decide which private key to use based on the network
  let deployerPK = process.env.DEPLOYER_PK;
  if (networkName === "mainnet" || networkName === "hardhat") {
    deployerPK = process.env.PROD_DEPLOYER_PK;
  }

  // Instantiate the signer from the deployer's PK
  const signer = new ethers.Wallet(deployerPK, ethers.provider);
  console.log(`Deployer Address: ${await signer.getAddress()}`);
  const deployerBalance = await ethers.provider.getBalance(await signer.getAddress());
  console.log(`Deployer Balance: ${ethers.formatEther(deployerBalance)} ETH\n`);

  let treasuryAddress, paymentTokenAddress, konduxRoyaltyAddress;

  /**
   * Configure addresses based on network
   */
  if (networkName === "mainnet" || networkName === "hardhat") {
    console.log("Using Mainnet-like addresses.\n");
    treasuryAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = MAINNET_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    konduxRoyaltyAddress = MAINNET_ADDRESSES.KONDUX_ROYALTY_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli") {
    console.log("Using testnet flow.\n");
    if (!IS_PRE_DEPLOYED) {
      /**
       * Example: Deploy mock contracts if you do NOT have pre-deployed addresses
       */
      // 1) Deploy a MockTreasury
      const MockTreasury = await ethers.getContractFactory("MockTreasury");
      const mockTreasury = await MockTreasury.connect(signer).deploy();
      await mockTreasury.waitForDeployment();
      treasuryAddress = mockTreasury.target;
      console.log(`MockTreasury deployed to: ${treasuryAddress}`);

      // 2) Deploy a MockKonduxERC20 (for payment)
      const MockKonduxERC20 = await ethers.getContractFactory("MockKonduxERC20");
      const mockPaymentToken = await MockKonduxERC20.connect(signer).deploy();
      await mockPaymentToken.waitForDeployment();
      paymentTokenAddress = mockPaymentToken.target;
      console.log(`MockKonduxERC20 deployed to: ${paymentTokenAddress}`);

      // 3) Set KonduxRoyaltyAddress (e.g. to deployer)
      konduxRoyaltyAddress = await signer.getAddress();
      console.log(`KonduxRoyaltyAddress set to deployer: ${konduxRoyaltyAddress}`);
    } else {
      // Use your predeployed addresses
      treasuryAddress = PREDEPLOYED_ADDRESSES.TREASURY_ADDRESS;
      paymentTokenAddress = PREDEPLOYED_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
      konduxRoyaltyAddress = PREDEPLOYED_ADDRESSES.KONDUX_ROYALTY_ADDRESS;
    }
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  console.log("Final addresses used:");
  console.log(`Treasury:            ${treasuryAddress}`);
  console.log(`Payment Token:       ${paymentTokenAddress}`);
  console.log(`Kondux Royalty Addr: ${konduxRoyaltyAddress}`);

  /**
   * Now deploy KonduxTieredPayments
   *
   * constructor(
   *   address _treasury,
   *   address governor,
   *   address _tokenAccepted,
   *   uint256 _lockPeriod,
   *   address _konduxRoyaltyAddress
   * );
   */
  console.log("\nDeploying KonduxTieredPayments...");

  const KonduxTieredPayments = await ethers.getContractFactory("KonduxTieredPayments");

  // Example: If mainnet/hardhat, use the mainnet ADMIN_ADDRESS; otherwise, use deployer as governor
  const governorAddress =
    networkName === "mainnet" || networkName === "hardhat"
      ? MAINNET_ADDRESSES.ADMIN_ADDRESS
      : await signer.getAddress();

  // Example lock period: 1 day (in seconds)
  const lockPeriod = 86400;

  console.log("Constructor arguments:");
  console.log(`  Treasury Address:        ${treasuryAddress}`);
  console.log(`  Governor Address:        ${governorAddress}`);
  console.log(`  Payment Token Accepted:  ${paymentTokenAddress}`);
  console.log(`  Lock Period:             ${lockPeriod} seconds`);
  console.log(`  Kondux Royalty Address:  ${konduxRoyaltyAddress}`);

  const konduxTieredPayments = await KonduxTieredPayments.connect(signer).deploy(
    treasuryAddress,
    governorAddress,
    paymentTokenAddress,
    lockPeriod,
    konduxRoyaltyAddress
  );
  await konduxTieredPayments.waitForDeployment();

  console.log(`\nKonduxTieredPayments deployed to: ${konduxTieredPayments.target}`);

  /**
   * Optional: Log constructor arguments for Hardhat verify
   */
  console.log("\nArguments for Hardhat verify:");
  console.log(
    `${treasuryAddress} ${governorAddress} ${paymentTokenAddress} ${lockPeriod} ${konduxRoyaltyAddress}`
  );

  console.log("\nDeployment completed successfully.\n");
}

// Run the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
