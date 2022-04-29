import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import fetch from 'node-fetch';
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import {
    Authority__factory,
    Kondux__factory,
    Minter__factory,
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log(await signer.getAddress(), "account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()), "ETH");

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    const minterDeployment = await deployments.get(CONTRACTS.minter);
    
    const authority = await Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = await Kondux__factory.connect(konduxNFTDeployment.address, signer);
    const minter = await Minter__factory.connect(minterDeployment.address, signer);

    // Step 1: Set base URI
    await waitFor(kondux.setBaseURI(CONFIGURATION.baseURI));
    console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURI);

    // Step 2: Set Minter
    await waitFor(kondux.setMinter(minter.address));
    console.log("Setup -- kondux.setMinter: set minter to " + minter.address);

    // Step 3: Merkle root
    const response = await fetch(CONFIGURATION.merkleRoot);
    const data: any = await response.json();
    await waitFor(minter.setRoot(data.root));
    console.log("Setup -- minter.setRoot: set merkle root to " + await minter.root());

    // Step 2: Set initial price
    await waitFor(minter.setPrice(CONFIGURATION.initialPrice));
    console.log("Setup -- minter.setPrice: set initial price to " + CONFIGURATION.initialPrice);
    
};

func.tags = ["setup", "production"];
func.dependencies = [CONTRACTS.kondux, CONTRACTS.minter];

export default func;
