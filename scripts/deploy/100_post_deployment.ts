import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import axios from "axios";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import {
    Authority__factory,
    Kondux__factory,
    Minter__factory,
    Treasury__factory,
    Staking__factory,
    KonduxERC20__factory
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);
    const signerAddress = await signer.getAddress();

    console.log(signerAddress, "account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()), "ETH");

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    const minterDeployment = await deployments.get(CONTRACTS.minter);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);
    
    const authority = await Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = await Kondux__factory.connect(konduxNFTDeployment.address, signer);
    const minter = await Minter__factory.connect(minterDeployment.address, signer);
    const treasury = await Treasury__factory.connect(treasuryDeployment.address, signer);
    const staking = await Staking__factory.connect(stakingDeployment.address, signer);
    const konduxERC20 = await KonduxERC20__factory.connect(konduxERC20Deployment.address, signer);

    // Step 1: Set base URI
    await waitFor(kondux.setBaseURI(CONFIGURATION.baseURI));
    console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURI);

    // Step 2: Set Minter
    await waitFor(kondux.setMinter(minterDeployment.address));
    console.log("Setup -- kondux.setMinter: set minter to " + minterDeployment.address);

    // Step 3: Merkle root
    const { data } = await axios.get(CONFIGURATION.merkleRoot);  
    await waitFor(minter.setRoot(data.root));
    console.log("Setup -- minter.setRoot: set merkle root to " + await minter.root());

    // Step 4: Set initial price
    await waitFor(minter.setPrice(CONFIGURATION.initialPrice));
    console.log("Setup -- minter.setPrice: set initial price to " + CONFIGURATION.initialPrice);

    // Step 5: Configure treasury
    await waitFor(treasury.setPermission(0, minterDeployment.address, true));
    console.log("Set minter as depositor");
    await waitFor(treasury.setPermission(0, stakingDeployment.address, true));
    console.log("Set staking as depositor");
    await waitFor(treasury.setPermission(1, signerAddress, true)); 
    console.log("Set deployer as spender");
    await waitFor(treasury.setPermission(1, stakingDeployment.address, true));
    console.log("Set staking as spender");
    await waitFor(treasury.setPermission(2, konduxERC20Deployment.address, true)); 
    console.log("Set konduxERC as reserve token");
};

func.tags = ["setup", "production"];
func.dependencies = [CONTRACTS.kondux, CONTRACTS.minter];

export default func;
