import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import {
    Authority__factory,
    Kondux__factory,
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log(await signer.getAddress(), "account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()), "ETH");

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    
    const authority = await Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = await Kondux__factory.connect(konduxNFTDeployment.address, signer);

    // Step 1: Set base URI
    await waitFor(kondux.setBaseURI(CONFIGURATION.baseURI, { from: deployer }));
    console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURI);


    
};

func.tags = ["setup", "production"];
func.dependencies = [CONTRACTS.kondux];

export default func;
