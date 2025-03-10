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

        const authorityDeployment = await deployments.get(CONTRACTS.authority);
        const konduxFoundersDeployment = await deployments.get(CONTRACTS.konduxFounders);
        const konduxDeployment = await deployments.get(CONTRACTS.kondux);
        const treasuryDeployment = await deployments.get(CONTRACTS.treasury);

        await deploy(CONTRACTS.minterFounders, {
            from: deployer,
            args: [
                authorityDeployment.address,
                konduxFoundersDeployment.address,
                konduxDeployment.address,
                treasuryDeployment.address
            ],
            log: true,
            skipIfAlreadyDeployed: true,
        });
    }
};

func.tags = [CONTRACTS.minterFounders, "NFT", "production"];
func.dependencies = [CONTRACTS.authority, CONTRACTS.konduxFounders, CONTRACTS.treasury];

export default func;
