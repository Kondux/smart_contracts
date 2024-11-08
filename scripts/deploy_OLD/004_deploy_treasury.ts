import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { ethers } from "hardhat";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    let authorityAddress;
    
    const network = await ethers.provider.getNetwork();
    
    if (network.chainId === CONFIGURATION.ethereumChainId) {
        authorityAddress = CONFIGURATION.authorityProduction;
    } else if (network.chainId === CONFIGURATION.sepoliaChainId) {
        authorityAddress = CONFIGURATION.authorityTestnet;
    } else {
        const authorityDeployment = await deployments.get(CONTRACTS.authority);
        authorityAddress = authorityDeployment.address;
    }

    await deploy(CONTRACTS.treasury, {
        from: deployer,
        args: [
            authorityAddress,
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.treasury, "NFT", "production"];
func.dependencies = [];

export default func;
