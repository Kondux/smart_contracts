import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxDeployment = await deployments.get(CONTRACTS.kondux);

    await deploy(CONTRACTS.minter, {
        from: deployer,
        args: [
            authorityDeployment.address,
            konduxDeployment.address
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.minter, "NFT", "production"];
func.dependencies = [CONTRACTS.authority, CONTRACTS.kondux];

export default func;