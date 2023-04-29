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

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    // const minterDeployment = await deployments.get(CONTRACTS.minter);
    // const marketplaceDeployment = await deployments.get(CONTRACTS.marketplace);  
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const konduxFoundersDeployment = await deployments.get(CONTRACTS.konduxFounders);
    const minterFoundersDeployment = await deployments.get(CONTRACTS.minterFounders);
    const minterPublicDeployment = await deployments.get(CONTRACTS.minterPublic);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.realKNDX_ERC20);
    const konduxERC721FoundersDeployment = await deployments.get(CONTRACTS.konduxERC721Founders);
    const helixDeployment = await deployments.get(CONTRACTS.helix);
    
    const network = await ethers.provider.getNetwork();

    const deployerAddress =  signer.getAddress();
    
    if (network.chainId !== CONFIGURATION.hardhatChainId) {
        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
            await delay(30e3); // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: authorityDeployment.address,
                constructorArguments: [
                    deployer,
                    deployer,
                    deployer,
                    deployer
                ],
            });
            console.log("Verified -- Authority");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- Authority");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            await hre.run("verify:verify", {
                address: konduxNFTDeployment.address,
                constructorArguments: [
                    CONFIGURATION.erc721,
                    CONFIGURATION.ticker                ],
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

        // try {
        //     await hre.run("verify:verify", {
        //         address: minterDeployment.address,
        //         constructorArguments: [
        //             authorityDeployment.address,
        //             konduxNFTDeployment.address,
        //             treasuryDeployment.address
        //         ],
        //     });
        //     console.log("Verified -- minter");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- minter");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        // try {
        //     await hre.run("verify:verify", {
        //         address: marketplaceDeployment.address,
        //         constructorArguments: [
        //             authorityDeployment.address,
        //         ],
        //     });
        //     console.log("Verified -- marketplace");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- marketplace");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        try {
            await hre.run("verify:verify", {
                address: stakingDeployment.address,
                constructorArguments: [
                    authorityDeployment.address,
                    konduxERC20Deployment.address,
                    treasuryDeployment.address,
                    konduxERC721FoundersDeployment.address,
                    konduxNFTDeployment.address,
                    helixDeployment.address,
                ],
            });
            console.log("Verified -- staking");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- staking");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            await hre.run("verify:verify", {
                address: treasuryDeployment.address,
                constructorArguments: [
                    authorityDeployment.address,
                ],
            });
            console.log("Verified -- treasury");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- treasury");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            await hre.run("verify:verify", {
                address: konduxFoundersDeployment.address,
                constructorArguments: [
                    CONFIGURATION.erc721Founders,
                     CONFIGURATION.tickerFounders,
                    authorityDeployment.address,
                ],
            });
            console.log("Verified -- konduxFounders");
        }
        catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- konduxFounders");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }


        try {
            await hre.run("verify:verify", {
                address: minterFoundersDeployment.address,
                constructorArguments: [
                    authorityDeployment.address,
                    konduxFoundersDeployment.address,
                    konduxNFTDeployment.address,
                    treasuryDeployment.address
                ],
            });
            console.log("Verified -- minterFounders");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- minterFounders");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }


        try {
            await hre.run("verify:verify", {
                address: minterPublicDeployment.address,
                constructorArguments: [
                    authorityDeployment.address,
                    konduxFoundersDeployment.address,
                    treasuryDeployment.address
                ],
            });
            console.log("Verified -- minterPublic");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- minterPublic");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            await hre.run("verify:verify", {
                address: konduxERC20Deployment.address,
                constructorArguments: [],
            });
            console.log("Verified -- konduxERC20");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- konduxERC20");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        try {
            await hre.run("verify:verify", {
                address: konduxERC721FoundersDeployment.address,
                constructorArguments: [],
                contract: "contracts/tests/KonduxERC721Founders.sol:KonduxERC721Founders"
            });
            console.log("Verified -- konduxERC721Founders");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- konduxERC721Founders");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }

        // try {
        //     await hre.run("verify:verify", {
        //         address: konduxERC721kNFTDeployment.address,
        //         constructorArguments: [],
        //         contract: "contracts/tests/KonduxERC721kNFT.sol:KonduxERC721kNFT"
        //     });
        //     console.log("Verified -- konduxERC721kNFT");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- konduxERC721kNFT");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        try {
            await hre.run("verify:verify", {
                address: helixDeployment.address,
                constructorArguments: [
                    CONFIGURATION.helixName,
                    CONFIGURATION.helixTicker
                ],
            });
            console.log("Verified -- helix");
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- helix");
                console.log(error.message);
            } else {
                throw error; // let others bubble up
            }                      
        }
    }    
};

func.tags = ["verify"];

export default func;
