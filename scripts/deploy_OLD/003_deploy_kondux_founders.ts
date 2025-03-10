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
        const authorityDeployment = await deployments.get(CONTRACTS.authority);

        await deploy(CONTRACTS.konduxFounders, {
            from: deployer,
            args: [
                CONFIGURATION.erc721Founders,
                CONFIGURATION.tickerFounders,
                authorityDeployment.address
            ],
            log: true,
            skipIfAlreadyDeployed: true,
        });
    }
};

func.tags = [CONTRACTS.konduxFounders, "NFT", "production"];
func.dependencies = [CONTRACTS.authority];

export default func;
