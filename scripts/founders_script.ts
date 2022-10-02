import hre from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import axios from "axios";
import { waitFor } from "./txHelper";
import { CONTRACTS, CONFIGURATION } from "./constants";
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
} from "../types";

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
    const minterDeployment = await deployments.get(CONTRACTS.minter);
    const minterFoundersDeployment = await deployments.get(CONTRACTS.minterFounders);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.konduxERC20);
    
    const authority = Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = Kondux__factory.connect(konduxNFTDeployment.address, signer);
    const minter = Minter__factory.connect(minterDeployment.address, signer);
    const konduxFounders = KonduxFounders__factory.connect(konduxFoundersNFTDeployment.address, signer);
    const minterFounders = MinterFounders__factory.connect(minterFoundersDeployment.address, signer);
    const treasury = Treasury__factory.connect(treasuryDeployment.address, signer);
    const staking = Staking__factory.connect(stakingDeployment.address, signer);
    const konduxERC20 = KonduxERC20__factory.connect(konduxERC20Deployment.address, signer);

    // Step 1: Set base URI
    await waitFor(konduxFounders.setBaseURI(CONFIGURATION.baseURI));
    console.log("Setup -- konduxFounders.setBaseURI: set baseURI to " + CONFIGURATION.baseURI);

    // Step 2: Set Minter
    await waitFor(authority.pushRole(minterFoundersDeployment.address, ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"))));
    console.log("Setup -- authority.setRole: set minter to " + minterFoundersDeployment.address);

    // Step 3: Merkle root
    const { data } = await axios.get(CONFIGURATION.merkleRoot);  
    console.log(data);
    await waitFor(minterFounders.setRoot(data.root));
    console.log("Setup -- minter.setRoot: set merkle root to " + await minterFounders.root());
    

    const dataOG= await axios.get(CONFIGURATION.merkleRootOG);
    const rootOg = dataOG.data.root;
    console.log("dataOG", dataOG.data.root);
    const rootOG = await minterFounders.setRoot(rootOg);
    await rootOG.wait();
    console.log("Setup -- minter.setRootOG: set merkle root to " + await minterFounders.rootOG());

    const dataWL1 = await axios.get(CONFIGURATION.merkleRootWL1); 
    console.log("dataWL1", dataWL1.data.root);
    await waitFor(minterFounders.setRoot(dataWL1.data.root));
    console.log("Setup -- minter.setRootWL1: set merkle root to " + await minterFounders.rootWL1());

    const dataWL2 = await axios.get(CONFIGURATION.merkleRootWL2);
    console.log("dataWL1", dataWL2.data.root);  
    await waitFor(minterFounders.setRoot(dataWL2.data.root));
    console.log("Setup -- minter.setRootWL2: set merkle root to " + await minterFounders.rootWL2());

    // Step 4: Set initial price
    await waitFor(minterFounders.setPrice(CONFIGURATION.initialPrice));
    console.log("Setup -- minter.setPrice: set initial price to " + CONFIGURATION.initialPrice);

    await waitFor(minterFounders.setPrice(CONFIGURATION.initialPrice));
    console.log("Setup -- minter.setPrice: set initial price to " + CONFIGURATION.initialPrice);

    console.log(await minterFounders.rootOG());

    // Step 5: Configure treasury
    await waitFor(treasury.setPermission(0, minterFoundersDeployment.address, true));
    console.log("Set minter founders as depositor");
    await waitFor(treasury.setPermission(1, signerAddress, true)); 
    console.log("Set deployer as spender");
};

func.tags = ["setup", "production"];

// run func() if called directly from command line
    func(hre)
