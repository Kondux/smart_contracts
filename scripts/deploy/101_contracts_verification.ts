import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import {
    Kondux__factory,
} from "../../types";

const delay = (ms: number | undefined) => new Promise(resolve => setTimeout(resolve, ms))

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    console.log("Account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()) + " ETH");

    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);     
    
    const network = await ethers.provider.getNetwork();
    
    if (network.chainId !== CONFIGURATION.hardhatChainId) {
        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
            await delay(30e3); // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: konduxNFTDeployment.address,
                constructorArguments: [
                    CONFIGURATION.erc721,
                    CONFIGURATION.ticker,
                ],
            });
            console.log("Verified -- kondux");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- kondux");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }
    }
    

    
};

func.tags = ["verify"];
func.dependencies = [CONTRACTS.kondux];

export default func;
