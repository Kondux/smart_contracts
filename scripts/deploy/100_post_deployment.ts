import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import axios from "axios";
import { waitFor } from "../txHelper";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { resolve } from 'path';
import {
    Authority__factory,
    Kondux__factory,
    KonduxFounders__factory,
    Minter__factory,
    MinterFounders__factory,
    Treasury__factory,
    Staking__factory,
    KonduxERC20__factory
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = ethers.provider.getSigner(deployer);
    const signerAddress = await signer.getAddress();

    console.log(signerAddress, "account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()), "ETH");

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const konduxNFTDeployment = await deployments.get(CONTRACTS.kondux);
    const konduxFoundersNFTDeployment = await deployments.get(CONTRACTS.konduxFounders);
    // const minterDeployment = await deployments.get(CONTRACTS.minter);
    const minterFoundersDeployment = await deployments.get(CONTRACTS.minterFounders);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    // const stakingDeployment = await deployments.get(CONTRACTS.staking);
    // const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);
    
    const authority = Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = Kondux__factory.connect(konduxNFTDeployment.address, signer);
    // const minter = Minter__factory.connect(minterDeployment.address, signer);
    const konduxFounders = KonduxFounders__factory.connect(konduxFoundersNFTDeployment.address, signer);
    const minterFounders = MinterFounders__factory.connect(minterFoundersDeployment.address, signer);
    const treasury = Treasury__factory.connect(treasuryDeployment.address, signer);
    // const staking = Staking__factory.connect(stakingDeployment.address, signer);
    // const konduxERC20 = KonduxERC20__factory.connect(konduxERC20Deployment.address, signer);

    // // Step 1: Set base URI
    await waitFor(kondux.setBaseURI(CONFIGURATION.baseURIkNFTBox));
    console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURIkNFTBox);                                                            
    await waitFor(konduxFounders.setBaseURI(CONFIGURATION.baseURIFounders));
    console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURIFounders);

    // // Step 2: Set Minter
    await waitFor(authority.pushRole(minterFoundersDeployment.address, ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"))));
    console.log("Setup -- authority.setRole: set minter to " + minterFoundersDeployment.address);

    // Step 3: Merkle root
    let { data } = await axios.get(CONFIGURATION.merkleRootFreeFounders);  
    console.log(data);
    await waitFor(minterFounders.setRootFreeFounders(data.root));
    console.log("Setup -- minter.merkleRootFreeFounders: set merkle root to " + await minterFounders.rootFreeFounders());
    

    let dataOG = await axios.get(CONFIGURATION.merkleRoot020);
    const rootOg = dataOG.data.root;
    console.log("rootFounders020", dataOG.data.root);
    const rootOG = await minterFounders.setRootFounders020(rootOg);
    await rootOG.wait();
    console.log("Setup -- minter.merkleRoot020: set merkle root to " + await minterFounders.rootFounders020());

    const data025 = await axios.get(CONFIGURATION.merkleRoot025); 
    console.log("rootFounders025", data025.data.root);
    await waitFor(minterFounders.setRootFounders025(data025.data.root));
    console.log("Setup -- minter.merkleRoot025: set merkle root to " + await minterFounders.rootFounders025());

    const dataWL2 = await axios.get(CONFIGURATION.merkleRootFreeKNFT);
    console.log("rootFreeKNFT", dataWL2.data.root);  
    await waitFor(minterFounders.setRootFreeKNFT(dataWL2.data.root));
    console.log("Setup -- minter.merkleRootFreeKNFT: set merkle root to " + await minterFounders.rootFreeKNFT());

    // Step 4: Set initial price
    await waitFor(minterFounders.setPriceFounders020(CONFIGURATION.initialPrice020));
    console.log("Setup -- minter.setPriceOG: set initial price to " + CONFIGURATION.initialPrice020);

    await waitFor(minterFounders.setPriceFounders025(CONFIGURATION.initialPrice025));
    console.log("Setup -- minter.setPriceWL1: set initial price to " + CONFIGURATION.initialPrice025);

    console.log(await minterFounders.rootFounders020());

    // Step 5: Configure treasury
    await waitFor(treasury.setPermission(0, minterFoundersDeployment.address, true));
    console.log("Set minter founders as depositor");
    // await waitFor(treasury.setPermission(0, stakingDeployment.address, true));
    // console.log("Set staking as depositor");
    await waitFor(treasury.setPermission(1, signerAddress, true)); 
    console.log("Set deployer as spender");
    // await waitFor(treasury.setPermission(1, stakingDeployment.address, true));
    // console.log("Set staking as spender");
    // await waitFor(treasury.setPermission(2, konduxERC20Deployment.address, true)); 
    // console.log("Set konduxERC as reserve token");
};

func.tags = ["setup", "production"];

export default func;
