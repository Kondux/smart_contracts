import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);


    await deploy(CONTRACTS.kondux, {
        from: deployer,
        args: [
            CONFIGURATION.erc721,
            CONFIGURATION.ticker,
            authorityDeployment.address
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.kondux, "NFT", "production"];
func.dependencies = [CONTRACTS.authority];

export default func;