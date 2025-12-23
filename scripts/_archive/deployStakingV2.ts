import "@nomicfoundation/hardhat-ethers";
import hre, { ethers, network } from "hardhat";
import { Signer } from "ethers";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import * as dotenv from "dotenv";

dotenv.config();

type AddressBook = {
  authority: string;
  konduxToken: string;
  treasury: string;
  foundersPass: string;
  knft: string;
  helix: string;
  label: string;
  deployDependencies?: boolean;
};

type DeploymentResult = {
  addresses: AddressBook;
  newlyDeployed: Array<{ name: string; address: string }>;
};

const PRESET_NETWORKS: Record<string, AddressBook> = {
  mainnet: {
    label: "Ethereum Mainnet",
    authority: "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A",
    konduxToken: "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
    treasury: "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
    foundersPass: "0x0fD5576c2842bD62dd00C5256491D11CcAD84306",
    knft: "0xeA6aB2871d5B3bbe6Ded740C812D85700Bae33c0",
    helix: "0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4",
  },
  sepolia: {
    label: "Sepolia Testnet",
    authority: "0x685a13093Ca561f531c93185B942a3F33385E14e",
    konduxToken: "0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc",
    treasury: "0xD5A6Af8F9C20CAF7872611D6773152AA50180F83",
    foundersPass: "0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499",
    knft: "0x5C7eD88DBbD99F513235A1911d41A5C57E2FFB78",
    helix: "0xb94F89750D9889656a6d081A0f06CBD3fA3Ad04b",
  },
};

const ROLE = {
  MINTER: ethers.id("MINTER_ROLE"),
  BURNER: ethers.id("BURNER_ROLE"),
};

const TREASURY_STATUS = {
  RESERVE_DEPOSITOR: 0,
  RESERVE_SPENDER: 1,
  RESERVE_TOKEN: 2,
};

async function resolveAddresses(
  signer: Signer,
  networkName: string
): Promise<DeploymentResult> {
  const eth = ethers;
  const normalized = networkName.toLowerCase();
  const preset = PRESET_NETWORKS[normalized];

  if (preset) {
    return {
      addresses: {
        ...preset,
        authority: eth.getAddress(preset.authority),
        konduxToken: eth.getAddress(preset.konduxToken),
        treasury: eth.getAddress(preset.treasury),
        foundersPass: eth.getAddress(preset.foundersPass),
        knft: eth.getAddress(preset.knft),
        helix: eth.getAddress(preset.helix),
      },
      newlyDeployed: [],
    };
  }

  return deployLocalDependencies(signer, networkName);
}

async function deployLocalDependencies(
  signer: Signer,
  networkName: string
): Promise<DeploymentResult> {
  console.log(`Locally provisioning dependencies for network '${networkName}'...`);

  const deployments: Array<{ name: string; address: string }> = [];

  const eth = ethers;

  const Authority = await eth.getContractFactory("Authority", signer);
  const authority = await Authority.deploy(
    await signer.getAddress(),
    await signer.getAddress(),
    await signer.getAddress(),
    await signer.getAddress()
  );
  await authority.waitForDeployment();
  const authorityAddress = await authority.getAddress();
  deployments.push({ name: "Authority", address: authorityAddress });

  const Treasury = await eth.getContractFactory("Treasury", signer);
  const treasury = await Treasury.deploy(authorityAddress);
  await treasury.waitForDeployment();
  const treasuryAddress = await treasury.getAddress();
  deployments.push({ name: "Treasury", address: treasuryAddress });

  const KNDX = await eth.getContractFactory("KNDX", signer);
  const kondux = await KNDX.deploy();
  await kondux.waitForDeployment();
  await waitFor(kondux.enableTrading(), "Kondux.enableTrading");
  const konduxAddress = await kondux.getAddress();
  deployments.push({ name: "KNDX", address: konduxAddress });

  const Helix = await eth.getContractFactory("Helix", signer);
  const helix = await Helix.deploy("Helix", "HLX");
  await helix.waitForDeployment();
  const helixAddress = await helix.getAddress();
  deployments.push({ name: "Helix", address: helixAddress });

  const Founders = await eth.getContractFactory("KonduxERC721Founders", signer);
  const founders = await Founders.deploy();
  await founders.waitForDeployment();
  const foundersAddress = await founders.getAddress();
  deployments.push({ name: "KonduxERC721Founders", address: foundersAddress });

  const KNFT = await eth.getContractFactory("KonduxERC721kNFT", signer);
  const knft = await KNFT.deploy();
  await knft.waitForDeployment();
  const knftAddress = await knft.getAddress();
  deployments.push({ name: "KonduxERC721kNFT", address: knftAddress });

  await waitFor(authority.pushVault(treasuryAddress, true), "Authority.pushVault");

  return {
    addresses: {
      label: `${networkName} (local sandbox)`,
      authority: authorityAddress,
      konduxToken: konduxAddress,
      treasury: treasuryAddress,
      foundersPass: foundersAddress,
      knft: knftAddress,
      helix: helixAddress,
      deployDependencies: true,
    },
    newlyDeployed: deployments,
  };
}

async function configureHelix(
  helixAddress: string,
  stakingAddress: string,
  signer: Signer
) {
  const helix = await ethers.getContractAt("Helix", helixAddress, signer);

  if (!(await helix.allowedContracts(stakingAddress))) {
    await waitFor(
      helix.setAllowedContract(stakingAddress, true),
      "Helix.setAllowedContract"
    );
    console.log(`Helix: whitelisted staking contract ${stakingAddress}`);
  } else {
    console.log("Helix: staking contract already whitelisted");
  }

  if (!(await helix.hasRole(ROLE.MINTER, stakingAddress))) {
    await waitFor(
      helix.setRole(ROLE.MINTER, stakingAddress, true),
      "Helix.grantMinter"
    );
    console.log("Helix: MINTER_ROLE granted");
  } else {
    console.log("Helix: MINTER_ROLE already granted");
  }

  if (!(await helix.hasRole(ROLE.BURNER, stakingAddress))) {
    await waitFor(
      helix.setRole(ROLE.BURNER, stakingAddress, true),
      "Helix.grantBurner"
    );
    console.log("Helix: BURNER_ROLE granted");
  } else {
    console.log("Helix: BURNER_ROLE already granted");
  }
}

async function configureTreasury(
  treasuryAddress: string,
  konduxToken: string,
  stakingAddress: string,
  signer: Signer
) {
  const treasury = await ethers.getContractAt("Treasury", treasuryAddress, signer);

  if (!(await treasury.permissions(TREASURY_STATUS.RESERVE_TOKEN, konduxToken))) {
    await waitFor(
      treasury.setPermission(
        TREASURY_STATUS.RESERVE_TOKEN,
        konduxToken,
        true
      ),
      "Treasury.addReserveToken"
    );
    console.log("Treasury: registered Kondux token as reserve");
  } else {
    console.log("Treasury: Kondux token already marked as reserve");
  }

  if (!(await treasury.permissions(TREASURY_STATUS.RESERVE_DEPOSITOR, stakingAddress))) {
    await waitFor(
      treasury.setPermission(
        TREASURY_STATUS.RESERVE_DEPOSITOR,
        stakingAddress,
        true
      ),
      "Treasury.addDepositor"
    );
    console.log("Treasury: StakingV2 added as depositor");
  } else {
    console.log("Treasury: StakingV2 already depositor");
  }

  if (!(await treasury.permissions(TREASURY_STATUS.RESERVE_SPENDER, stakingAddress))) {
    await waitFor(
      treasury.setPermission(
        TREASURY_STATUS.RESERVE_SPENDER,
        stakingAddress,
        true
      ),
      "Treasury.addSpender"
    );
    console.log("Treasury: StakingV2 added as spender");
  } else {
    console.log("Treasury: StakingV2 already spender");
  }

  const currentStaking = await treasury.stakingContract();
  if (currentStaking.toLowerCase() !== stakingAddress.toLowerCase()) {
    await waitFor(
      treasury.setStakingContract(stakingAddress),
      "Treasury.setStakingContract"
    );
    console.log(`Treasury: staking contract updated from ${currentStaking} to ${stakingAddress}`);
  } else {
    console.log("Treasury: staking contract already configured");
  }

  await waitFor(
    treasury.erc20ApprovalSetup(konduxToken, ethers.MaxUint256),
    "Treasury.erc20ApprovalSetup"
  );
  console.log("Treasury: unlimited allowance granted to StakingV2");
}

async function waitFor(txPromise: Promise<any> | any, label: string) {
  const tx = await txPromise;
  if (!tx || typeof tx.wait !== "function") {
    return;
  }
  const receipt = await tx.wait();
  console.log(`${label}: tx ${receipt?.hash ?? "<no hash>"}`);
}

async function main() {
  const networkName = network.name;
  const [signer] = (await (hre.ethers as any).getSigners()) as HardhatEthersSigner[];
  const deployer = await signer.getAddress();
  const balance = await (hre.ethers as any).provider.getBalance(deployer);

  console.log(`Deploying StakingV2 to '${networkName}' as ${deployer}`);
  console.log(`Deployer balance: ${ethers.formatEther(balance)} ETH`);

  const { addresses, newlyDeployed } = await resolveAddresses(signer, networkName);

  console.log("\nUsing dependency addresses:");
  console.table([
    { key: "Authority", address: addresses.authority },
    { key: "KonduxToken", address: addresses.konduxToken },
    { key: "Treasury", address: addresses.treasury },
    { key: "FoundersPass", address: addresses.foundersPass },
    { key: "kNFT", address: addresses.knft },
    { key: "Helix", address: addresses.helix },
  ]);

  if (newlyDeployed.length) {
    console.log("\nLocally deployed helpers:");
    console.table(newlyDeployed.map(({ name, address }) => ({ name, address })));
  }

  const StakingV2 = await ethers.getContractFactory("StakingV2", signer);
  const stakingV2 = await StakingV2.deploy(
    addresses.authority,
    addresses.konduxToken,
    addresses.treasury,
    addresses.foundersPass,
    addresses.knft,
    addresses.helix
  );
  await stakingV2.waitForDeployment();
  const stakingAddress = await stakingV2.getAddress();
  console.log(`\nStakingV2 deployed at: ${stakingAddress}`);

  await configureHelix(addresses.helix, stakingAddress, signer);
  await configureTreasury(addresses.treasury, addresses.konduxToken, stakingAddress, signer);

  console.log("\nDeployment summary:");
  console.table([
    { item: "Network", value: addresses.label ?? networkName },
    { item: "StakingV2", value: stakingAddress },
    { item: "Authority", value: addresses.authority },
    { item: "KonduxToken", value: addresses.konduxToken },
    { item: "Treasury", value: addresses.treasury },
    { item: "FoundersPass", value: addresses.foundersPass },
    { item: "kNFT", value: addresses.knft },
    { item: "Helix", value: addresses.helix },
  ]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
