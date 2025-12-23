// ignition/KonduxTokenBasedMinter.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "hardhat";

export default buildModule("KonduxTokenBasedMinter", (m) => {
  // Define addresses based on network
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

  const TESTNET_ADDRESSES = {
    WETH_ADDRESS: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    UNISWAP_V2_ROUTER_ADDRESS: "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008",
  };

  // Get the signer
  const signer = m.getSigner({
    // You can specify a specific private key here if needed
  });

  // Deploy or get existing contract addresses based on network
  let kNFTAddress,
    foundersPassAddress,
    treasuryAddress,
    paymentTokenAddress,
    uniswapPairAddress,
    WETHAddress,
    UNISWAP_V2_ROUTER_ADDRESS;

  if (m.network.name === "mainnet") {
    console.log("Using Mainnet existing contract addresses.");
    kNFTAddress = MAINNET_ADDRESSES.KNFT_ADDRESS;
    foundersPassAddress = MAINNET_ADDRESSES.FOUNDERSPASS_ADDRESS;
    treasuryAddress = MAINNET_ADDRESSES.TREASURY_ADDRESS;
    paymentTokenAddress = MAINNET_ADDRESSES.PAYMENT_TOKEN_ADDRESS;
    uniswapPairAddress = MAINNET_ADDRESSES.UNISWAP_PAIR_ADDRESS;
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (m.network.name === "sepolia" || m.network.name === "goerli") {
    console.log("Deploying mock contracts for Testnet.");

    const mockKondux = await m.deploy("MockKondux", {
      contract: "MockKondux",
      args: [],
    });
    kNFTAddress = mockKondux.target;

    const mockFoundersPass = await m.deploy("MockFoundersPass", {
      contract: "MockFoundersPass",
      args: [],
    });
    foundersPassAddress = mockFoundersPass.target;

    const mockTreasury = await m.deploy("MockTreasury", {
      contract: "MockTreasury",
      args: [],
    });
    treasuryAddress = mockTreasury.target;

    const mockPaymentToken = await m.deploy("MockKonduxERC20", {
      contract: "MockKonduxERC20",
      args: [],
    });
    paymentTokenAddress = mockPaymentToken.target;

    uniswapPairAddress = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else {
    throw new Error(`Unsupported network: ${m.network.name}`);
  }

  // Set WETH and Uniswap V2 Router addresses based on network
  if (m.network.name === "mainnet") {
    WETHAddress = MAINNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = MAINNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  } else if (m.network.name === "sepolia" || m.network.name === "goerli") {
    WETHAddress = TESTNET_ADDRESSES.WETH_ADDRESS;
    UNISWAP_V2_ROUTER_ADDRESS = TESTNET_ADDRESSES.UNISWAP_V2_ROUTER_ADDRESS;
  }

  // Deploy KonduxTokenBasedMinter
  const konduxTokenBasedMinter = await m.deploy("KonduxTokenBasedMinter", {
    contract: "KonduxTokenBasedMinter",
    args: [
      kNFTAddress,
      foundersPassAddress,
      treasuryAddress,
      paymentTokenAddress,
      uniswapPairAddress,
      WETHAddress,
    ],
  });

  // Grant MINTER_ROLE to KonduxTokenBasedMinter
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const kNFTContract = await m.getContractAt("Kondux", kNFTAddress); // Or MockKondux
  await kNFTContract.grantRole(MINTER_ROLE, konduxTokenBasedMinter.target);

  // Create Liquidity Pool on Testnet
  if (m.network.name === "sepolia" || m.network.name === "goerli") {
    const mintAmount = ethers.parseUnits("1000000", 9);
    const mockPaymentToken = await m.getContractAt(
      "MockKonduxERC20",
      paymentTokenAddress
    );
    await mockPaymentToken.mint(await signer.getAddress(), mintAmount);

    const tokenAmount = mintAmount;
    const ethAmount = ethers.parseEther("0.001");

    await m.execute(async (hre) => {
      // This function needs to be defined within the Ignition module or imported
      async function createLiquidityPool(
        routerAddress: string,
        tokenAddress: string,
        tokenAmount: bigint,
        ethAmount: bigint,
        signer: any // Replace 'any' with the correct type
      ) {
        console.log("Creating Liquidity Pool on Uniswap V2...");

        const IUniswapV2Router02 = [
          "function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)",
        ];

        const router = new ethers.Contract(
          routerAddress,
          IUniswapV2Router02,
          signer
        );

        const tokenContract = await ethers.getContractAt(
          "MockKonduxERC20",
          tokenAddress,
          signer
        );
        const approvalTx = await tokenContract.approve(
          routerAddress,
          tokenAmount
        );
        await approvalTx.wait();

        const deadline = Math.floor(Date.now() / 1000) + 60 * 20;

        const tx = await router.addLiquidityETH(
          tokenAddress,
          tokenAmount,
          (tokenAmount * 95n) / 100n,
          (ethAmount * 95n) / 100n,
          await signer.getAddress(),
          deadline,
          { value: ethAmount }
        );

        const receipt = await tx.wait();
        console.log("Liquidity Pool created successfully.");
      }

      await createLiquidityPool(
        UNISWAP_V2_ROUTER_ADDRESS,
        paymentTokenAddress,
        tokenAmount,
        ethAmount,
        signer
      );
    });
  }
});