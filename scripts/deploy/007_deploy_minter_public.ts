import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxFoundersDeployment = await deployments.get(CONTRACTS.konduxFounders);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);


    await deploy(CONTRACTS.minterPublic, {
        from: deployer,
        args: [
            authorityDeployment.address,
            konduxFoundersDeployment.address,
            treasuryDeployment.address
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.minterPublic, "NFT", "production"];
func.dependencies = [CONTRACTS.authority, CONTRACTS.konduxFounders, CONTRACTS.treasury];

export default func;
