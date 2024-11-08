import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { ethers } from "hardhat";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    let authorityAddress, konduxERC20Address, konduxERC721FoundersAddress;
    
    const network = await ethers.provider.getNetwork();
    
    if (network.chainId === CONFIGURATION.ethereumChainId) {
        authorityAddress = CONFIGURATION.authorityProduction;
        konduxERC20Address = CONFIGURATION.konduxERC20Production;
        konduxERC721FoundersAddress = CONFIGURATION.foundersERC721Production;
    } else if (network.chainId === CONFIGURATION.sepoliaChainId) {
        authorityAddress = CONFIGURATION.authorityTestnet;
        konduxERC20Address = CONFIGURATION.konduxERC20Testnet;
        konduxERC721FoundersAddress = CONFIGURATION.foundersERC721Testnet;
    } else {
        const authorityDeployment = await deployments.get(CONTRACTS.authority);
        authorityAddress = authorityDeployment.address;
        const konduxERC20Deployment = await deployments.get(CONTRACTS.realKNDX_ERC20);
        konduxERC20Address = konduxERC20Deployment.address;
        const konduxERC721FoundersDeployment = await deployments.get(CONTRACTS.konduxERC721Founders);
        konduxERC721FoundersAddress = konduxERC721FoundersDeployment.address;
    }

    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const konduxERC721kNFTDeployment = await deployments.get(CONTRACTS.kondux);
    const helix = await deployments.get(CONTRACTS.helix);

    await deploy(CONTRACTS.staking, {
        from: deployer,
        args: [
            authorityAddress,
            konduxERC20Address,
            treasuryDeployment.address,
            konduxERC721FoundersAddress,
            konduxERC721kNFTDeployment.address,
            helix.address
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.staking, "migration", "production"];

export default func;