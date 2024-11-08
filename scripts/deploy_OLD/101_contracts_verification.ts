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

    let authorityAddress, konduxERC20Address, foundersERC721Address, kboxERC721Address, minterFoundersAddress, minterPublicAddress, treasuryAddress, stakingAddress, helixAddress, knftAddress;
    
    const network = await ethers.provider.getNetwork();
    
    if (network.chainId === CONFIGURATION.ethereumChainId) {
        authorityAddress = CONFIGURATION.authorityProduction;
        konduxERC20Address = CONFIGURATION.konduxERC20Production;
        foundersERC721Address = CONFIGURATION.foundersERC721Production;
        kboxERC721Address = CONFIGURATION.kboxERC721Production;
        minterFoundersAddress = CONFIGURATION.minterFoundersProduction;
        minterPublicAddress = CONFIGURATION.minterPublicProduction;
        // treasuryAddress = CONFIGURATION.treasuryProduction;
        // stakingAddress = CONFIGURATION.stakingProduction;
        // helixAddress = CONFIGURATION.helixProduction;        
        // knftAddress = CONFIGURATION.knftProduction;        
    } else if (network.chainId === CONFIGURATION.sepoliaChainId) {
        authorityAddress = CONFIGURATION.authorityTestnet;
        konduxERC20Address = CONFIGURATION.konduxERC20Testnet;
        foundersERC721Address = CONFIGURATION.foundersERC721Testnet;
        kboxERC721Address = CONFIGURATION.kboxERC721Testnet;
        minterFoundersAddress = CONFIGURATION.minterFoundersTestnet;
        minterPublicAddress = CONFIGURATION.minterPublicTestnet;
        // treasuryAddress = CONFIGURATION.treasuryTestnet;
        // stakingAddress = CONFIGURATION.stakingTestnet;
        // helixAddress = CONFIGURATION.helixTestnet;
        // knftAddress = CONFIGURATION.knftTestnet;
        // const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
        // knftAddress = konduxNFTDeployment.address;
    } else {
        const authorityDeployment = await deployments.get(CONTRACTS.authority);
        authorityAddress = authorityDeployment.address;
        const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
        knftAddress = konduxNFTDeployment.address;
        const konduxERC20Deployment = await deployments.get(CONTRACTS.realKNDX_ERC20);
        konduxERC20Address = konduxERC20Deployment.address;
        const konduxERC721FoundersDeployment = await deployments.get(CONTRACTS.konduxERC721Founders);
        foundersERC721Address = konduxERC721FoundersDeployment.address;        
        const minterFoundersDeployment = await deployments.get(CONTRACTS.minterFounders);
        minterFoundersAddress = minterFoundersDeployment.address;
        const minterPublicDeployment = await deployments.get(CONTRACTS.minterPublic);
        minterPublicAddress = minterPublicDeployment.address;    
    }

    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    treasuryAddress = treasuryDeployment.address;
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    stakingAddress = stakingDeployment.address;
    const helixDeployment = await deployments.get(CONTRACTS.helix);
    helixAddress = helixDeployment.address;
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    knftAddress = konduxNFTDeployment.address;

    const deployerAddress =  signer.getAddress();
    
    if (network.chainId !== CONFIGURATION.hardhatChainId) {
        console.log("Sleepin' for 30 seconds to wait for the chain to be ready...");
        await delay(30e3); // 30 seconds delay to allow the network to be synced
        // try {
        //     await hre.run("verify:verify", {
        //         address: authorityDeployment.address,
        //         constructorArguments: [
        //             deployer,
        //             deployer,
        //             deployer,
        //             deployer
        //         ],
        //     });
        //     console.log("Verified -- Authority");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- Authority");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        try {
            await hre.run("verify:verify", {
                address: knftAddress,
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
                address: stakingAddress,
                constructorArguments: [
                    authorityAddress,
                    konduxERC20Address,
                    treasuryDeployment.address,
                    foundersERC721Address,
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
                address: treasuryAddress,
                constructorArguments: [
                    authorityAddress,
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

        // try {
        //     await hre.run("verify:verify", {
        //         address: konduxFoundersDeployment.address,
        //         constructorArguments: [
        //             CONFIGURATION.erc721Founders,
        //              CONFIGURATION.tickerFounders,
        //             authorityDeployment.address,
        //         ],
        //     });
        //     console.log("Verified -- konduxFounders");
        // }
        // catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- konduxFounders");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }


        // try {
        //     await hre.run("verify:verify", {
        //         address: minterFoundersDeployment.address,
        //         constructorArguments: [
        //             authorityDeployment.address,
        //             konduxFoundersDeployment.address,
        //             konduxNFTDeployment.address,
        //             treasuryDeployment.address
        //         ],
        //     });
        //     console.log("Verified -- minterFounders");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- minterFounders");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }


        // try {
        //     await hre.run("verify:verify", {
        //         address: minterPublicDeployment.address,
        //         constructorArguments: [
        //             authorityDeployment.address,
        //             konduxFoundersDeployment.address,
        //             treasuryDeployment.address
        //         ],
        //     });
        //     console.log("Verified -- minterPublic");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- minterPublic");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        // try {
        //     await hre.run("verify:verify", {
        //         address: konduxERC20Deployment.address,
        //         constructorArguments: [],
        //     });
        //     console.log("Verified -- konduxERC20");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- konduxERC20");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

        // try {
        //     await hre.run("verify:verify", {
        //         address: konduxERC721FoundersDeployment.address,
        //         constructorArguments: [],
        //         contract: "contracts/tests/KonduxERC721Founders.sol:KonduxERC721Founders"
        //     });
        //     console.log("Verified -- konduxERC721Founders");
        // } catch (error) {
        //     if (error instanceof NomicLabsHardhatPluginError) {
        //         // specific error
        //         console.log("Error verifying -- konduxERC721Founders");
        //         console.log(error.message);
        //     } else {
        //         throw error; // let others bubble up
        //     }                      
        // }

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
                address: helixAddress,
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
