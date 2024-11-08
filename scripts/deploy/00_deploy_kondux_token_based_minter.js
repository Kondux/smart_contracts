const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const networkName = hre.network.name;
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

  if (["mainnet", "hardhat"].includes(networkName)) {
    console.log("Using Mainnet existing contract addresses.");

    kNFTAddress = MAINNET_ADDRESSES.KNFT_ADDRESS;
    foundersPassAddress = MAINNET_ADDRESSES.FOUNDERSPASS_ADDRESS;
    treasuryAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = MAINNET_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    uniswapPairAddress = MAINNET_ADDRESSES.UNISWAP_PAIR_ADDRESS;
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (["sepolia", "goerli"].includes(networkName)) {
    console.log("Deploying mock contracts for Testnet.");

    // Deploy MockKondux
    const mockKonduxDeployment = await deploy("MockKondux", {
      from: deployer,
      log: true,
      deterministicDeployment: false,
    });
    kNFTAddress = mockKonduxDeployment.address;
    console.log(`MockKondux deployed to: ${kNFTAddress}`);

    // Deploy MockFoundersPass
    const mockFoundersPassDeployment = await deploy("MockFoundersPass", {
      from: deployer,
      log: true,
      deterministicDeployment: false,
    });
    foundersPassAddress = mockFoundersPassDeployment.address;
    console.log(`MockFoundersPass deployed to: ${foundersPassAddress}`);

    // Deploy MockTreasury
    const mockTreasuryDeployment = await deploy("MockTreasury", {
      from: deployer,
      log: true,
      deterministicDeployment: false,
    });
    treasuryAddress = mockTreasuryDeployment.address;
    console.log(`MockTreasury deployed to: ${treasuryAddress}`);

    // Deploy MockKonduxERC20
    const mockPaymentTokenDeployment = await deploy("MockKonduxERC20", {
      from: deployer,
      log: true,
      deterministicDeployment: false,
    });
    paymentTokenAddress = mockPaymentTokenDeployment.address;
    console.log(`MockKonduxERC20 deployed to: ${paymentTokenAddress}`);

    // Use predefined Testnet Uniswap V2 Router address
    uniswapPairAddress = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
    console.log(`Using Testnet UniswapV2 Router Address: ${uniswapPairAddress}`);
  } else {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  // Define WETH and Uniswap V2 Router addresses based on network
  if (["mainnet", "hardhat"].includes(networkName)) {
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (["sepolia", "goerli"].includes(networkName)) {
    WETHAddress = TESTNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  }
  console.log(`WETH Address: ${WETHAddress}`);
  console.log(`Uniswap V2 Router Address: ${UNISWAP_V2_ROUTER_ADDRESS}`);

  // Deploy KonduxTokenBasedMinter
  console.log("Deploying KonduxTokenBasedMinter...");
  const konduxTokenBasedMinterDeployment = await deploy("KonduxTokenBasedMinter", {
    from: deployer,
    args: [
      kNFTAddress,
      foundersPassAddress,
      treasuryAddress,
      paymentTokenAddress,
      uniswapPairAddress,
      WETHAddress,
    ],
    log: true,
    deterministicDeployment: false,
  });
  console.log(`KonduxTokenBasedMinter deployed to: ${konduxTokenBasedMinterDeployment.address}`);

  // Grant MINTER_ROLE to KonduxTokenBasedMinter on the Kondux NFT contract
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  console.log(`Granting MINTER_ROLE to KonduxTokenBasedMinter on Kondux NFT contract. Role: ${MINTER_ROLE}`);

  if (["mainnet", "hardhat"].includes(networkName)) {
    await execute(
      "Kondux",
      { from: deployer, log: true },
      "grantRole",
      MINTER_ROLE,
      konduxTokenBasedMinterDeployment.address
    );
    console.log(`Granted MINTER_ROLE to KonduxTokenBasedMinter on Kondux NFT contract.`);
  } else if (["sepolia", "goerli"].includes(networkName)) {
    await execute(
      "MockKondux",
      { from: deployer, log: true },
      "grantRole",
      MINTER_ROLE,
      konduxTokenBasedMinterDeployment.address
    );
    console.log(`Granted MINTER_ROLE to KonduxTokenBasedMinter on MockKondux NFT contract.`);
  }

  // If deploying to Testnet, create Liquidity Pool
  if (["sepolia", "goerli"].includes(networkName)) {
    console.log("Creating Liquidity Pool on Uniswap V2 for Testnet.");

    // Interact with the signer (deployer)
    const signer = ethers.provider.getSigner(deployer);

    // Mint 1,000,000 MockKonduxERC20 tokens to the deployer's address
    const mockPaymentToken = await ethers.getContract("MockKonduxERC20", deployer);
    const mintAmount = ethers.parseUnits("1000000", 9); // 1,000,000 tokens with 9 decimals
    console.log(`Minting ${ethers.formatUnits(mintAmount, 9)} MockKonduxERC20 tokens to ${deployer}...`);
    await mockPaymentToken.connect(signer).mint(deployer, mintAmount);
    console.log(`Minted ${ethers.formatUnits(mintAmount, 9)} MockKonduxERC20 tokens to ${deployer}.`);

    // Define amounts for liquidity
    const tokenAmount = mintAmount; // 1,000,000 tokens
    const ethAmount = ethers.parseEther("0.01"); // 0.01 ETH

    // Create Liquidity Pool
    await createLiquidityPool(
      UNISWAP_V2_ROUTER_ADDRESS,
      paymentTokenAddress,
      tokenAmount,
      ethAmount,
      signer
    );
  }

  // Verification Steps
  console.log("Verifying contracts on Etherscan...");
  if (["sepolia", "goerli"].includes(networkName)) {
    // Verify MockKonduxERC20
    await run("verify:verify", {
      address: paymentTokenAddress,
      constructorArguments: [],
    });

    // Verify MockKondux
    await run("verify:verify", {
      address: kNFTAddress,
      constructorArguments: [],
    });

    // Verify MockFoundersPass
    await run("verify:verify", {
      address: foundersPassAddress,
      constructorArguments: [],
    });

    // Verify MockTreasury
    await run("verify:verify", {
      address: treasuryAddress,
      constructorArguments: [],
    });

    // Verify KonduxTokenBasedMinter
    await run("verify:verify", {
      address: konduxTokenBasedMinterDeployment.address,
      constructorArguments: [
        kNFTAddress,
        foundersPassAddress,
        treasuryAddress,
        paymentTokenAddress,
        uniswapPairAddress,
        WETHAddress,
      ],
    });
  } else if (["mainnet", "hardhat"].includes(networkName)) {
    // Verify KonduxTokenBasedMinter
    await run("verify:verify", {
      address: konduxTokenBasedMinterDeployment.address,
      constructorArguments: [
        kNFTAddress,
        foundersPassAddress,
        treasuryAddress,
        paymentTokenAddress,
        uniswapPairAddress,
        WETHAddress,
      ],
    });

    // Verify Kondux (if needed)
    await run("verify:verify", {
      address: kNFTAddress,
      constructorArguments: [],
    });
  }

  console.log("Deployment and verification completed successfully.\n");
};

module.exports.tags = ["KonduxTokenBasedMinter"];
