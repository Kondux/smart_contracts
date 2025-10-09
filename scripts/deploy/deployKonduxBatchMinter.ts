import { config as dotenvConfig } from "dotenv";
import hre from "hardhat";
import path from "path";
import { promises as fs } from "fs";
import { Wallet } from "ethers";

const { ethers, network } = hre;
const provider: any = (hre as any).ethers.provider ?? (hre as any).network.provider;

function delay(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

dotenvConfig();

type NormalizedNetwork = "mainnet" | "sepolia" | "hardhat";

type HexAddress = `0x${string}`;

interface ExistingAddresses {
  AUTHORITY_ADDRESS: HexAddress;
  ADMIN_ADDRESS?: HexAddress;
  TREASURY_ADDRESS: HexAddress;
  FOUNDERSPASS_ADDRESS: HexAddress;
  PAYMENT_TOKEN_ADDRESS: HexAddress;
  UNISWAP_PAIR_ADDRESS?: HexAddress;
  UNISWAP_V2_ROUTER_ADDRESS: HexAddress;
  WETH_ADDRESS: HexAddress;
  KNFT_ADDRESS?: HexAddress;
  HELIX_ADDRESS?: HexAddress;
  PARTNER_WALLET_ADDRESS?: HexAddress;
}

interface NetworkConfig {
  label: string;
  kondux: {
    name: string;
    symbol: string;
    maxSupply: bigint;
    baseURI?: string;
  };
  addresses: ExistingAddresses;
  options: {
    createPairIfMissing?: boolean;
    batchRoleRecipients?: HexAddress[];
    konduxRoleRecipients?: HexAddress[];
    revokeDeployerAdmin?: boolean;
    enableFreeMinting?: boolean;
  };
}

interface AddressBookEntry {
  version: string;
  chainId: number;
  konduxImplementation: HexAddress;
  konduxBatchMinter: HexAddress;
  konduxName: string;
  konduxSymbol: string;
  authority: HexAddress;
  admin?: HexAddress;
  treasury: HexAddress;
  foundersPass: HexAddress;
  paymentToken: HexAddress;
  weth: HexAddress;
  uniswapPair: HexAddress;
  uniswapRouter: HexAddress;
  notes?: string;
}

interface AddressBookShape {
  schema: string;
  networks: Record<NormalizedNetwork, AddressBookEntry[]>;
}

const TESTNET_ADMIN_FALLBACK = (process.env.USER_ADDRESS ?? "0x9767a2B120614F526e923DAAF89843EC7C2292d7") as HexAddress;

const NETWORK_CONFIG: Record<NormalizedNetwork, NetworkConfig> = {
  mainnet: {
    label: "Ethereum Mainnet",
    kondux: {
      name: "Kondux kNFT",
      symbol: "kNFT",
      maxSupply: 0n,
      baseURI: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
    },
    addresses: {
      AUTHORITY_ADDRESS: "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A",
      ADMIN_ADDRESS: "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
      KNFT_ADDRESS: "0x5aD180dF8619CE4f888190C3a926111a723632ce",
      TREASURY_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
      FOUNDERSPASS_ADDRESS: "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
      PAYMENT_TOKEN_ADDRESS: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
      UNISWAP_PAIR_ADDRESS: "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
      WETH_ADDRESS: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      UNISWAP_V2_ROUTER_ADDRESS: "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
      PARTNER_WALLET_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
    },
    options: {
      createPairIfMissing: false,
      batchRoleRecipients: ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
      konduxRoleRecipients: ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
      revokeDeployerAdmin: true,
      enableFreeMinting: false,
    },
  },
  sepolia: {
    label: "Ethereum Sepolia",
    kondux: {
      name: "Kondux kNFT (Sepolia)",
      symbol: "kNFTs",
      maxSupply: 0n,
      baseURI: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
    },
    addresses: {
      AUTHORITY_ADDRESS: "0xfF0b8218353F088173779B0079263F672Aa3B548",
      ADMIN_ADDRESS: TESTNET_ADMIN_FALLBACK,
      TREASURY_ADDRESS: "0xD5A6Af8F9C20CAF7872611D6773152AA50180F83",
      FOUNDERSPASS_ADDRESS: "0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499",
      PAYMENT_TOKEN_ADDRESS: "0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc",
      UNISWAP_V2_ROUTER_ADDRESS: "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008",
      WETH_ADDRESS: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
      HELIX_ADDRESS: "0xb94F89750D9889656a6d081A0f06CBD3fA3Ad04b",
      PARTNER_WALLET_ADDRESS: "0xD5A6Af8F9C20CAF7872611D6773152AA50180F83",
    },
    options: {
      createPairIfMissing: true,
      batchRoleRecipients: [TESTNET_ADMIN_FALLBACK],
      konduxRoleRecipients: [TESTNET_ADMIN_FALLBACK],
      revokeDeployerAdmin: false,
      enableFreeMinting: false,
    },
  },
  hardhat: {
    label: "Hardhat (Mainnet Fork)",
    kondux: {
      name: "Kondux kNFT",
      symbol: "kNFT",
      maxSupply: 0n,
      baseURI: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
    },
    addresses: {
      AUTHORITY_ADDRESS: "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A",
      ADMIN_ADDRESS: "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
      KNFT_ADDRESS: "0x5aD180dF8619CE4f888190C3a926111a723632ce",
      TREASURY_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
      FOUNDERSPASS_ADDRESS: "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
      PAYMENT_TOKEN_ADDRESS: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
      UNISWAP_PAIR_ADDRESS: "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
      WETH_ADDRESS: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      UNISWAP_V2_ROUTER_ADDRESS: "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
      PARTNER_WALLET_ADDRESS: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
    },
    options: {
      createPairIfMissing: false,
      batchRoleRecipients: ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
      konduxRoleRecipients: ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
      revokeDeployerAdmin: false,
      enableFreeMinting: false,
    },
  },
};

const ADDRESS_BOOK_PATH = path.resolve(
  __dirname,
  "../../docs/deployments/kondux-batchminter/address-book.json"
);

function normalizeNetwork(name: string, chainId: number): NormalizedNetwork {
  if (name === "homestead" || chainId === 1) return "mainnet";
  if (name === "sepolia" || chainId === 11155111) return "sepolia";
  if (name === "hardhat" || name === "localhost") return "hardhat";
  throw new Error(`Unsupported network "${name}" (chainId ${chainId})`);
}

function assertAddress(addr: string, label: string): HexAddress {
  if (!ethers.isAddress(addr)) {
    throw new Error(`${label} is not a valid address: ${addr}`);
  }
  return ethers.getAddress(addr) as HexAddress;
}

async function selectSigner(networkKey: NormalizedNetwork) {
  const useProdKey = networkKey === "mainnet" || networkKey === "hardhat";
  const envKey = useProdKey ? "PROD_DEPLOYER_PK" : "DEPLOYER_PK";
  const pk = process.env[envKey];
  if (!pk || pk.trim().length === 0) {
    throw new Error(`Missing ${envKey} in environment for ${networkKey} deployment`);
  }
  const signer = new Wallet(pk, provider);

  if (networkKey === "hardhat") {
    const desired = ethers.parseEther("1000");
    const current = await provider.getBalance(await signer.getAddress());
    if (current < ethers.parseEther("100")) {
      await provider.send("hardhat_setBalance", [
        await signer.getAddress(),
        ethers.toBeHex(desired),
      ]);
    }
  }

  return signer;
}

async function resolveUniswapPair(
  signer: Wallet,
  config: NetworkConfig
): Promise<HexAddress> {
  const existing = config.addresses.UNISWAP_PAIR_ADDRESS;
  if (existing && existing !== ethers.ZeroAddress) {
    return assertAddress(existing, "UNISWAP_PAIR_ADDRESS");
  }

  const routerAddress = assertAddress(
    config.addresses.UNISWAP_V2_ROUTER_ADDRESS,
    "UNISWAP_V2_ROUTER_ADDRESS"
  );
  const router = new ethers.Contract(
    routerAddress,
    [
      "function factory() external view returns (address)",
    ],
    signer
  );

  const factoryAddress = await router.factory();
  const factory = new ethers.Contract(
    factoryAddress,
    [
      "function getPair(address tokenA, address tokenB) external view returns (address)",
      "function createPair(address tokenA, address tokenB) external returns (address)",
    ],
    signer
  );

  const weth = assertAddress(config.addresses.WETH_ADDRESS, "WETH_ADDRESS");
  const kndx = assertAddress(config.addresses.PAYMENT_TOKEN_ADDRESS, "PAYMENT_TOKEN_ADDRESS");

  let pair: string = await factory.getPair(weth, kndx);
  if (pair !== ethers.ZeroAddress) {
    return ethers.getAddress(pair) as HexAddress;
  }

  if (!config.options.createPairIfMissing) {
    throw new Error(
      `Uniswap pair for ${weth} and ${kndx} not found. Provide UNISWAP_PAIR_ADDRESS or enable createPairIfMissing.`
    );
  }

  console.log(
    `Uniswap pair not found. Creating new pair via factory ${factoryAddress}...`
  );
  const tx = await factory.createPair(weth, kndx);
  const receipt = await tx.wait();
  console.log(`Uniswap pair creation tx hash: ${receipt?.hash}`);

  pair = await factory.getPair(weth, kndx);
  if (!pair || pair === ethers.ZeroAddress) {
    throw new Error("Pair creation reported success but returned zero address");
  }
  console.log(`New Uniswap pair detected at ${pair}`);
  return ethers.getAddress(pair) as HexAddress;
}

async function appendAddressBookEntry(
  networkKey: NormalizedNetwork,
  entry: AddressBookEntry
) {
  let book: AddressBookShape;
  try {
    const raw = await fs.readFile(ADDRESS_BOOK_PATH, "utf8");
    book = JSON.parse(raw) as AddressBookShape;
  } catch (err) {
    book = {
      schema: "kondux-batchminter-address-book",
      networks: {
        mainnet: [],
        hardhat: [],
        sepolia: [],
      },
    };
  }

  if (!book.networks[networkKey]) {
    book.networks[networkKey] = [];
  }
  book.networks[networkKey].push(entry);

  await fs.mkdir(path.dirname(ADDRESS_BOOK_PATH), { recursive: true });
  await fs.writeFile(ADDRESS_BOOK_PATH, `${JSON.stringify(book, null, 2)}\n`, "utf8");
}

async function grantDefaultAdmin(
  contract: any,
  adminAddress: HexAddress | undefined,
  signerAddress: string,
  revokeDeployer: boolean,
  label: string
) {
  if (!adminAddress || adminAddress.toLowerCase() === signerAddress.toLowerCase()) {
    return;
  }

  const adminRole = await contract.DEFAULT_ADMIN_ROLE();
  const tx = await contract.grantRole(adminRole, adminAddress);
  const receipt = await tx.wait();
  console.log(`${label}: granted DEFAULT_ADMIN_ROLE to ${adminAddress} (tx: ${receipt.hash})`);

  if (revokeDeployer) {
    const revokeTx = await contract.revokeRole(adminRole, signerAddress);
    const revokeReceipt = await revokeTx.wait();
    console.log(`${label}: revoked DEFAULT_ADMIN_ROLE from deployer (tx: ${revokeReceipt.hash})`);
  }
}

async function grantRoleIfNeeded(
  contract: any,
  role: string,
  target: HexAddress,
  label: string
) {
  const hasRole = await contract.hasRole(role, target);
  if (hasRole) {
    console.log(`${label}: ${target} already has role ${role}`);
    return;
  }
  const tx = await contract.grantRole(role, target);
  const receipt = await tx.wait();
  console.log(`${label}: granted role ${role} to ${target} (tx: ${receipt.hash})`);
}

async function applyKonduxPostSetup(
  kondux: any,
  config: NetworkConfig,
  partnerWallet?: HexAddress
) {
  if (config.kondux.baseURI) {
    const currentBaseUri: string = await kondux.baseURI();
    if (currentBaseUri === config.kondux.baseURI) {
      console.log(`KonduxImplementation: baseURI already set to ${config.kondux.baseURI}`);
    } else {
      const tx = await kondux.setBaseURI(config.kondux.baseURI);
      const receipt = await tx.wait();
      console.log(`KonduxImplementation: baseURI set to ${config.kondux.baseURI} (tx: ${receipt.hash})`);
    }
  }

  if (partnerWallet) {
    const currentPartner: string = await kondux.partnerWallet();
    if (currentPartner?.toLowerCase() !== partnerWallet.toLowerCase()) {
      const tx = await kondux.setPartnerWallet(partnerWallet);
      const receipt = await tx.wait();
      console.log(`KonduxImplementation: partner wallet set to ${partnerWallet} (tx: ${receipt.hash})`);
    } else {
      console.log(`KonduxImplementation: partner wallet already ${partnerWallet}`);
    }
  }

  if (typeof config.options.enableFreeMinting === "boolean") {
    const currentFreeMinting: boolean = await kondux.freeMinting();
    if (currentFreeMinting !== config.options.enableFreeMinting) {
      const tx = await kondux.setFreeMinting(config.options.enableFreeMinting);
      const receipt = await tx.wait();
      console.log(`KonduxImplementation: freeMinting set to ${config.options.enableFreeMinting} (tx: ${receipt.hash})`);
    } else {
      console.log(`KonduxImplementation: freeMinting already ${currentFreeMinting}`);
    }
  }
}

async function main() {
  const networkInfo = await provider.getNetwork();
  const networkKey = normalizeNetwork(network.name, Number(networkInfo.chainId));
  const config = NETWORK_CONFIG[networkKey];
  if (!config) {
    throw new Error(`Missing configuration for network ${networkKey}`);
  }

  const signer = await selectSigner(networkKey);
  const signerAddress = await signer.getAddress();
  const authorityAddress = assertAddress(config.addresses.AUTHORITY_ADDRESS, "AUTHORITY_ADDRESS");
  const adminAddress = config.addresses.ADMIN_ADDRESS
    ? assertAddress(config.addresses.ADMIN_ADDRESS, "ADMIN_ADDRESS")
    : undefined;
  const partnerWallet = config.addresses.PARTNER_WALLET_ADDRESS
    ? assertAddress(config.addresses.PARTNER_WALLET_ADDRESS, "PARTNER_WALLET_ADDRESS")
    : undefined;

  console.log(`\n=== Kondux BatchMinter Deployment | ${config.label} ===`);
  console.log(`Network chainId: ${networkInfo.chainId}`);
  console.log(`Deployer: ${signerAddress}`);
  console.log(
    `Deployer balance: ${ethers.formatEther(await provider.getBalance(signerAddress))} ETH`
  );

  const pairAddress = await resolveUniswapPair(signer, config);
  console.log(`Using Uniswap pair address: ${pairAddress}`);

  const konduxFactory = await ethers.getContractFactory("KonduxImplementation", signer);
  const konduxImplementation = (await konduxFactory.deploy()) as any;
  await konduxImplementation.waitForDeployment();
  const konduxAddress = konduxImplementation.target as HexAddress;
  console.log(`KonduxImplementation deployed at ${konduxAddress}`);

  const initTx = await konduxImplementation.initialize(
    config.kondux.name,
    config.kondux.symbol,
    pairAddress,
    assertAddress(config.addresses.WETH_ADDRESS, "WETH_ADDRESS"),
    assertAddress(config.addresses.PAYMENT_TOKEN_ADDRESS, "PAYMENT_TOKEN_ADDRESS"),
    assertAddress(config.addresses.FOUNDERSPASS_ADDRESS, "FOUNDERSPASS_ADDRESS"),
    assertAddress(config.addresses.TREASURY_ADDRESS, "TREASURY_ADDRESS"),
    config.kondux.maxSupply
  );
  await initTx.wait();
  console.log(`KonduxImplementation initialised (${initTx.hash})`);

  const batchFactory = await ethers.getContractFactory("KonduxBatchMinter", signer);
  const batchMinter = (await batchFactory.deploy(
    konduxAddress,
    authorityAddress
  )) as any;
  await batchMinter.waitForDeployment();
  const batchAddress = batchMinter.target as HexAddress;
  console.log(`KonduxBatchMinter deployed at ${batchAddress}`);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  await grantRoleIfNeeded(
    konduxImplementation,
    MINTER_ROLE,
    batchAddress,
    "KonduxImplementation"
  );

  if (config.options.konduxRoleRecipients) {
    for (const addr of config.options.konduxRoleRecipients) {
      await grantRoleIfNeeded(
        konduxImplementation,
        MINTER_ROLE,
        assertAddress(addr, "konduxRoleRecipient"),
        "KonduxImplementation"
      );
    }
  }

  const BATCH_MINTER_ROLE = ethers.keccak256(
    ethers.toUtf8Bytes("BATCH_MINTER_ROLE")
  );

  if (config.options.batchRoleRecipients) {
    for (const addr of config.options.batchRoleRecipients) {
      await grantRoleIfNeeded(
        batchMinter,
        BATCH_MINTER_ROLE,
        assertAddress(addr, "batchRoleRecipient"),
        "KonduxBatchMinter"
      );
    }
  }

  await applyKonduxPostSetup(konduxImplementation, config, partnerWallet);

  await grantDefaultAdmin(
    konduxImplementation,
    adminAddress,
    signerAddress,
    Boolean(config.options.revokeDeployerAdmin),
    "KonduxImplementation"
  );

  await grantDefaultAdmin(
    batchMinter,
    adminAddress,
    signerAddress,
    Boolean(config.options.revokeDeployerAdmin),
    "KonduxBatchMinter"
  );

  const version = new Date().toISOString();
  await appendAddressBookEntry(networkKey, {
    version,
    chainId: Number(networkInfo.chainId),
    konduxImplementation: konduxAddress,
    konduxBatchMinter: batchAddress,
    konduxName: config.kondux.name,
    konduxSymbol: config.kondux.symbol,
    authority: authorityAddress,
    admin: adminAddress,
    treasury: assertAddress(config.addresses.TREASURY_ADDRESS, "TREASURY_ADDRESS"),
    foundersPass: assertAddress(
      config.addresses.FOUNDERSPASS_ADDRESS,
      "FOUNDERSPASS_ADDRESS"
    ),
    paymentToken: assertAddress(
      config.addresses.PAYMENT_TOKEN_ADDRESS,
      "PAYMENT_TOKEN_ADDRESS"
    ),
    weth: assertAddress(config.addresses.WETH_ADDRESS, "WETH_ADDRESS"),
    uniswapPair: pairAddress,
    uniswapRouter: assertAddress(
      config.addresses.UNISWAP_V2_ROUTER_ADDRESS,
      "UNISWAP_V2_ROUTER_ADDRESS"
    ),
    notes: `Kondux implementation + batch minter deployed via deployKonduxBatchMinter.ts with signer ${signerAddress}`,
  });

  const isEtherscanNetwork = networkKey === "mainnet" || networkKey === "sepolia";
  const attemptVerification = async (
    label: string,
    address: HexAddress,
    constructorArguments: readonly unknown[],
    waitMs: number,
    fullyQualifiedName?: string
  ) => {
    if (!isEtherscanNetwork) {
      return;
    }

    if (waitMs > 0) {
      console.log(`${label}: waiting ${waitMs / 1000}s before submitting verification...`);
      await delay(waitMs);
    }

    try {
      await hre.run("verify:verify", {
        address,
        constructorArguments,
        contract: fullyQualifiedName,
      });
      console.log(`${label}: verification request sent to Etherscan.`);
    } catch (error: any) {
      const message = error?.message ?? String(error);
      if (message.toLowerCase().includes("already verified")) {
        console.log(`${label}: already verified on Etherscan.`);
      } else {
        console.warn(`${label}: verification failed – ${message}`);
      }
    }
  };

  await attemptVerification(
    "KonduxImplementation",
    konduxAddress,
    [],
    networkKey === "mainnet" ? 40000 : 20000,
    "contracts/KonduxImplementation.sol:KonduxImplementation"
  );

  await attemptVerification(
    "KonduxBatchMinter",
    batchAddress,
    [konduxAddress, authorityAddress],
    7000,
    "contracts/KonduxBatchMinter.sol:KonduxBatchMinter"
  );

  console.log("\nDeployment summary:");
  console.log(`  KonduxImplementation: ${konduxAddress}`);
  console.log(`  KonduxBatchMinter  : ${batchAddress}`);
  console.log(`  Address book entry version: ${version}`);

  console.log("\nVerification args:");
  console.log(
    `  npx hardhat verify --network ${networkKey === "hardhat" ? "mainnet" : networkKey} ${konduxAddress}`
  );
  console.log(
    `  npx hardhat verify --network ${networkKey === "hardhat" ? "mainnet" : networkKey} ${batchAddress} ${konduxAddress} ${config.addresses.AUTHORITY_ADDRESS}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
