import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    // const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);

    // await deploy(CONTRACTS.staking, {
    //     from: deployer,
    //     args: [
    //         authorityDeployment.address,
    //         konduxERC20Deployment.address
    //     ],
    //     log: true,
    //     skipIfAlreadyDeployed: true,
    // });
};

func.tags = [CONTRACTS.staking, "migration", "production"];

export default func;