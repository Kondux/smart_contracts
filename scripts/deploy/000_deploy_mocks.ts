import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy(CONTRACTS.realKNDX_ERC20, {
        from: deployer,
        args: [],
        log: true,
        skipIfAlreadyDeployed: true,
    });

    await deploy(CONTRACTS.konduxERC721Founders, {
        from: deployer,
        args: [],
        log: true,
        skipIfAlreadyDeployed: true,
    });

};

func.tags = [CONTRACTS.konduxERC20];

export default func;