import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

     await deploy(CONTRACTS.helix, {
         from: deployer,
         args: [
             CONFIGURATION.helixName,
             CONFIGURATION.helixTicker         ],
         log: true,
         skipIfAlreadyDeployed: true,
     });
};

func.tags = [CONTRACTS.helix, "Helix", "production"];
func.dependencies = [];

export default func;
