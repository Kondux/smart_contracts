const { ethers, network } = require("hardhat");
require("dotenv").config();

async function createLiquidityPool(
  routerAddress,
  tokenAddress,
  tokenAmount,
  ethAmount,
  signer
) {
  console.log("Creating Liquidity Pool on Uniswap V2...");

  // Uniswap V2 Router Interface
  const IUniswapV2Router02 = [
    "function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)",
  ];

  const router = new ethers.Contract(routerAddress, IUniswapV2Router02, signer);

  // Approve the router to spend tokens
  const tokenContract = await ethers.getContractAt("MockKonduxERC20", tokenAddress, signer);
  const approvalTx = await tokenContract.approve(routerAddress, tokenAmount);
  await approvalTx.wait();
  console.log(`Approved Uniswap Router to spend ${ethers.formatUnits(tokenAmount, 9)} tokens.`);

  // Add Liquidity
  const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

  const tx = await router.addLiquidityETH(
    tokenAddress,
    tokenAmount,
    tokenAmount * 95n / 100n, // Accepting 95% of tokenAmount as min
    ethAmount * 95n / 100n,   // Accepting 95% of ethAmount as min
    await signer.getAddress(),
    deadline,
    { value: ethAmount }
  );

  const receipt = await tx.wait();
  console.log("Liquidity Pool created successfully.");
  console.log(`Transaction Hash: ${receipt.hash}`);
  console.log(`LP Address: ${receipt.logs[0].pair}`);
    return receipt.logs[0].pair;
}

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

  const PREDEPLOYED_ADDRESSES = {
    KNFT_ADDRESS: "0xDDAEc4bfe0D64A234F49F2fe1d22c42126089Ac1",
    TREASURY_ADDRESS: "0x57B2FF8afF3b8A3307E2aE7bf0854167922aCf96",
    FOUNDERSPASS_ADDRESS: "0xBE983455A9FF94480510Be64Ee4df75F444638AF",
    PAYMENT_TOKEN_ADDRESS: "0x7601584C416aFC4DB0299964ceBD0aD2C7Da2500",
    UNISWAP_PAIR_ADDRESS: "0xD5714c7dE4297199F08B0c7250DecFd3a4902718",
  };

  const IS_PRE_DEPLOYED = true;

  let deployerPK = process.env.DEPLOYER_PK;
    if (networkName === "mainnet" || networkName === "hardhat") {
        deployerPK = process.env.PROD_DEPLOYER_PK;
    }

    // Instatiate the wallet from the deployer's private key (from .env file DEPLOYER_PK or PROD_DEPLOYER_PK for mainnet)
    const signer = new ethers.Wallet(deployerPK, ethers.provider);

    // use the signer to perform every action on the current provider
    console.log(`Deployer Address: ${await signer.getAddress()}`);
    console.log(`Deployer Balance: ${ethers.formatEther(await ethers.provider.getBalance(await signer.getAddress()))} ETH`);

  let kNFTAddress,
    foundersPassAddress,
    treasuryAddress,
    paymentTokenAddress,
    uniswapPairAddress,
    WETHAddress,
    UNISWAP_V2_ROUTER_ADDRESS;

  if (networkName === "mainnet" || networkName === "hardhat") {
    console.log("Using Mainnet existing contract addresses.");

    kNFTAddress = MAINNET_ADDRESSES.KNFT_ADDRESS;
    foundersPassAddress = MAINNET_ADDRESSES.FOUNDERSPASS_ADDRESS;
    treasuryAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = MAINNET_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    uniswapPairAddress = MAINNET_ADDRESSES.UNISWAP_PAIR_ADDRESS;
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli" ) {
    console.log("Deploying mock contracts for Testnet.");
    if (!IS_PRE_DEPLOYED) {
        // Deploy MockKondux
        // const MockKondux = await ethers.getContractFactory("MockKondux");
        // const mockKondux = await MockKondux.connect(signer).deploy();
        // await mockKondux.waitForDeployment();
        // kNFTAddress = mockKondux.target;
        // console.log(`MockKondux deployed to: ${kNFTAddress}`);


        // Deploy MockFoundersPass
        const MockFoundersPass = await ethers.getContractFactory("MockFoundersPass");
        const mockFoundersPass = await MockFoundersPass.connect(signer).deploy();
        await mockFoundersPass.waitForDeployment();
        foundersPassAddress = mockFoundersPass.target;
        console.log(`MockFoundersPass deployed to: ${foundersPassAddress}`);

        // Deploy MockTreasury
        const MockTreasury = await ethers.getContractFactory("MockTreasury");
        const mockTreasury = await MockTreasury.connect(signer).deploy();
        await mockTreasury.waitForDeployment();
        treasuryAddress = mockTreasury.target;
        console.log(`MockTreasury deployed to: ${treasuryAddress}`);

        // Deploy MockKonduxERC20
        const MockKonduxERC20 = await ethers.getContractFactory("MockKonduxERC20");
        const mockPaymentToken = await MockKonduxERC20.connect(signer).deploy();
        await mockPaymentToken.waitForDeployment();
        paymentTokenAddress = mockPaymentToken.target;
        console.log(`MockKonduxERC20 deployed to: ${paymentTokenAddress}`);

        
      
    }

    // Use predefined Testnet Uniswap V2 Router address
    uniswapPairAddress = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
    console.log(`Using Testnet UniswapV2 Router Address: ${uniswapPairAddress}`);
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  // Define WETH and Uniswap V2 Router addresses based on network
  if (networkName === "mainnet" || networkName === "hardhat") {
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (networkName === "sepolia" || networkName === "goerli") {
    WETHAddress = TESTNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  }
  console.log(`WETH Address: ${WETHAddress}`);
  console.log(`Uniswap V2 Router Address: ${UNISWAP_V2_ROUTER_ADDRESS}`);

  if (IS_PRE_DEPLOYED && (networkName === "sepolia" || networkName === "goerli")) {
    foundersPassAddress = PREDEPLOYED_ADDRESSES.FOUNDERSPASS_ADDRESS;
    treasuryAddress = PREDEPLOYED_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = PREDEPLOYED_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    uniswapPairAddress = PREDEPLOYED_ADDRESSES.UNISWAP_PAIR_ADDRESS;
  }

   // If deploying to Testnet or Hardhat, create Liquidity Pool
   if ((networkName === "sepolia" || networkName === "goerli") && !IS_PRE_DEPLOYED) {
    console.log("Creating Liquidity Pool on Uniswap V2 for Testnet.");

    // Instatiate the wallet from the deployer's private key (from .env file DEPLOYER_PK or PROD_DEPLOYER_PK for mainnet)
    let deployerPK = process.env.DEPLOYER_PK;
    if (networkName === "mainnet") {
        deployerPK = process.env.PROD_DEPLOYER_PK;
    }
    const signer = new ethers.Wallet(deployerPK, ethers.provider);
    console.log(`Deployer Address: ${await signer.getAddress()}`);
    console.log(`Deployer Balance: ${ethers.formatEther(await signer.getBalance())} ETH`);
    
    // Mint 1,000,000 MockKonduxERC20 tokens to the deployer's address
    const mockPaymentToken = await ethers.getContractAt("MockKonduxERC20", paymentTokenAddress, signer);
    const mintAmount = ethers.parseUnits("100000", 18); // 1,000,000 tokens with 9 decimals
    console.log(`Minting ${mintAmount} MockKonduxERC20 tokens to ${await signer.getAddress()}...`);
    const mintTx = await mockPaymentToken.connect(signer).mint(await signer.getAddress(), mintAmount);
    await mintTx.wait();
    console.log(`Minted ${ethers.formatUnits(mintAmount, 9)} MockKonduxERC20 tokens to ${await signer.getAddress()}.`);

    // Define amounts for liquidity
    const tokenAmount = mintAmount; // 1 tokens
    const ethAmount = ethers.parseEther("0.001"); // 0.01 ETH

    // Create Liquidity Pool
    uniswapPairAddress = await createLiquidityPool(
        UNISWAP_V2_ROUTER_ADDRESS,
        paymentTokenAddress,
        tokenAmount,
        ethAmount,
        signer
    );

  }

// ------------------------------------------------------------------------------
// 1) DEPLOY THE "Kondux" NFT CONTRACT (maxSupply = 1000, royalties + lending = enabled)
// ------------------------------------------------------------------------------
console.log("\nDeploying Kondux NFT contract ...");

const Kondux = await ethers.getContractFactory("Kondux");

/**
 * constructor(
 *   string memory _name,
 *   string memory _symbol,
 *   address _uniswapPair,
 *   address _weth,
 *   address _kndx,
 *   address _foundersPass,
 *   address _treasury,
 *   uint256 _maxSupply
 * )
 */

const kondux = await Kondux.connect(signer).deploy(
    "KonduxAvatar",          // _name
    "KNDX_AVATAR",               // _symbol
    uniswapPairAddress,   // _uniswapPair
    WETHAddress,          // _weth
    paymentTokenAddress,  // _kndx (the ERC20 token used to pay royalties)
    foundersPassAddress,  // _foundersPass
    treasuryAddress,      // _treasury
    1000                  // _maxSupply
);
 console.log("Arguments for hardhat verify:");
    console.log(`KonduxAvatar KNDX_AVATAR ${uniswapPairAddress} ${WETHAddress} ${paymentTokenAddress} ${foundersPassAddress} ${treasuryAddress} 1000`);
await kondux.waitForDeployment();
kNFTAddress = kondux.target;
console.log(`Kondux NFT contract deployed to: ${kNFTAddress}`);

  // Deploy KonduxHybridMinter
  console.log("Deploying KonduxHybridMinter...");
  const KonduxHybridMinter = await ethers.getContractFactory("KonduxHybridMinter");
  console.log("Deploying KonduxHybridMinter with the following arguments:");
  console.log(`kNFTAddress: ${kNFTAddress}`);
  console.log(`foundersPassAddress: ${foundersPassAddress}`);
  console.log(`treasuryAddress: ${treasuryAddress}`);
  console.log(`paymentTokenAddress: ${paymentTokenAddress}`);
  console.log(`uniswapPairAddress: ${uniswapPairAddress}`);
  console.log(`WETHAddress: ${WETHAddress}`);

  const merkleRoot = ethers.sha256(ethers.toUtf8Bytes("merkleRoot"));
  console.log(`merkleRoot: ${merkleRoot}`);

  const konduxHybridMinter = await KonduxHybridMinter.connect(signer).deploy(
    kNFTAddress,
    treasuryAddress,
    paymentTokenAddress,
    uniswapPairAddress,
    WETHAddress,
    // 0.01 ETH for the minting fee
    ethers.parseEther("0.01"), // 0.01 ETH
    10, // 10% discount for KNDX ERC20 payment
    ethers.sha256(ethers.toUtf8Bytes("merkleRoot")) // merkleRoot
  );
  console.log("Arguments for hardhat verify:");
    console.log(`${kNFTAddress} ${treasuryAddress} ${paymentTokenAddress} ${uniswapPairAddress} ${WETHAddress} 10000000000000000 10 ${merkleRoot}`);
  await konduxHybridMinter.waitForDeployment();
  console.log(`KonduxHybridMinter deployed to: ${konduxHybridMinter.target}`);

  // Grant MINTER_ROLE to KonduxHybridMinter on the Kondux NFT contract
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  if (networkName === "mainnet" || networkName === "hardhat") {
    const kNFTContract = await ethers.getContractAt("Kondux", kNFTAddress);
    const grantTx = await kNFTContract.connect(signer).grantRole(MINTER_ROLE, konduxHybridMinter.target);
    await grantTx.wait();
    console.log(`Granted MINTER_ROLE to KonduxHybridMinter on Kondux NFT contract.`);
  } else if ((networkName === "sepolia" || networkName === "goerli") ) {
    const mockKondux = await ethers.getContractAt("MockKondux", kNFTAddress);
    const grantTx = await mockKondux.connect(signer).grantRole(MINTER_ROLE, konduxHybridMinter.target);
    await grantTx.wait();
    console.log(`Granted MINTER_ROLE to KonduxHybridMinter on MockKondux NFT contract.`);
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
