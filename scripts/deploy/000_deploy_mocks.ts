import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { ethers } from "hardhat";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const network = await ethers.provider.getNetwork();
    
    if (network.chainId !== CONFIGURATION.ethereumChainId && network.chainId !== CONFIGURATION.sepoliaChainId) {  
        await deploy(CONTRACTS.realKNDX_ERC20, {
            from: deployer,
            args: [],
            log: true,
            skipIfAlreadyDeployed: false,
        });

        await deploy(CONTRACTS.konduxERC721Founders, {
            from: deployer,
            args: [],
            log: true,
            skipIfAlreadyDeployed: true,
        });

    }

};

func.tags = [CONTRACTS.konduxERC20];

export default func;