import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const konduxERC721FoundersDeployment = await deployments.get(CONTRACTS.konduxERC721Founders);
    const konduxERC721kNFTDeployment = await deployments.get(CONTRACTS.konduxERC721kNFT);
    const helix = await deployments.get(CONTRACTS.helix);

    await deploy(CONTRACTS.staking, {
        from: deployer,
        args: [
            authorityDeployment.address,
            konduxERC20Deployment.address,
            treasuryDeployment.address,
            konduxERC721FoundersDeployment.address,
            konduxERC721kNFTDeployment.address,
            helix.address
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.staking, "migration", "production"];

export default func;