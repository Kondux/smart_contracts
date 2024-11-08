import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { ethers } from "hardhat";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const network = await ethers.provider.getNetwork();
    
    if (network.chainId !== CONFIGURATION.ethereumChainId && network.chainId !== CONFIGURATION.sepoliaChainId) {         
        await deploy(CONTRACTS.authority, {
            from: deployer,
            args: [deployer, deployer, deployer, deployer],
            log: true,
            skipIfAlreadyDeployed: true,
        });
    }

};

func.tags = [CONTRACTS.authority, "migration", "production"];

export default func;