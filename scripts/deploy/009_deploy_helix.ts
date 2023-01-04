import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);


     await deploy(CONTRACTS.helix, {
         from: deployer,
         args: [
             CONFIGURATION.helixName,
             CONFIGURATION.helixTicker,
             authorityDeployment.address
         ],
         log: true,
         skipIfAlreadyDeployed: false,
     });
};

func.tags = [CONTRACTS.helix, "Helix", "production"];
func.dependencies = [CONTRACTS.authority];

export default func;
