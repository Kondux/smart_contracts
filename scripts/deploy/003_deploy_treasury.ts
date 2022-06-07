import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);

    await deploy(CONTRACTS.treasury, {
        from: deployer,
        args: [
            authorityDeployment.address,
            konduxERC20Deployment.address
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.treasury, "NFT", "production"];
func.dependencies = [CONTRACTS.authority, CONTRACTS.konduxERC20];

export default func;
