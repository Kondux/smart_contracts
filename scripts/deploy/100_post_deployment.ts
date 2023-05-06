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
    // Minter__factory,
    MinterFounders__factory,
    MinterPublic__factory,
    Treasury__factory,
    Staking__factory,
    KonduxERC20__factory,
    KNDX__factory,
    KonduxERC721Founders__factory,
    KonduxERC721kNFT__factory,
    Helix__factory,
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
    const minterPublicDeployment = await deployments.get(CONTRACTS.minterPublic);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const konduxERC20Deployment = await deployments.get(CONTRACTS.realKNDX_ERC20);
    const konduxERC721FoundersDeployment = await deployments.get(CONTRACTS.konduxERC721Founders);
    const helixDeployment = await deployments.get(CONTRACTS.helix);
    
    const authority = Authority__factory.connect(authorityDeployment.address, signer);
    console.log("Authority Governor Address:", await authority.governor());

    const kondux = Kondux__factory.connect(konduxNFTDeployment.address, signer);
    // const minter = Minter__factory.connect(minterDeployment.address, signer);
    const konduxFounders = KonduxFounders__factory.connect(konduxFoundersNFTDeployment.address, signer);
    const minterFounders = MinterFounders__factory.connect(minterFoundersDeployment.address, signer);
    const minterPublic = MinterPublic__factory.connect(minterPublicDeployment.address, signer);
    const treasury = Treasury__factory.connect(treasuryDeployment.address, signer);
    const staking = Staking__factory.connect(stakingDeployment.address, signer);
    const helix = Helix__factory.connect(helixDeployment.address, signer);

    // Testing only
    const konduxERC20 = KNDX__factory.connect(konduxERC20Deployment.address, signer);
    const konduxERC721Founders = KonduxERC721Founders__factory.connect(konduxERC721FoundersDeployment.address, signer);

    // // // Step 1: Set base URI
    // await waitFor(kondux.setBaseURI(CONFIGURATION.baseURIkNFTBox)); // PRODUCTION
    // console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION. baseURIkNFTBox);  // PRODUCTION                                                          
    // await waitFor(konduxFounders.setBaseURI(CONFIGURATION.baseURIFounders)); // PRODUCTION
    // console.log("Setup -- kondux.setBaseURI: set baseURI to " + CONFIGURATION.baseURIFounders); // PRODUCTION

    // // Step 2: Set Minter
    await waitFor(authority.pushRole(minterFoundersDeployment.address, ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")))); // PRODUCTION
    console.log("Setup -- authority.setRole: set minter to " + minterFoundersDeployment.address);
    await waitFor(authority.pushRole(minterPublicDeployment.address, ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"))));
    console.log("Setup -- authority.setRole: set minter to " + minterPublicDeployment.address);
    await waitFor(authority.pushRole(staking.address, ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")))); // setting staking as minter to mint helix
    console.log("Setup -- authority.setRole: set minter to " + staking.address);

    // // // Step 3: Merkle root
    // let { data } = await axios.get(CONFIGURATION.merkleRootFreeFounders);  
    // console.log(data);
    // await waitFor(minterFounders.setRootFreeFounders(data.root)); // PRODUCTION
    // console.log("Setup -- minter.merkleRootFreeFounders: set merkle root to " + await minterFounders.rootFreeFounders());
    

    // let dataOG = await axios.get(CONFIGURATION.merkleRoot020);
    // const rootOg = dataOG.data.root;
    // console.log("rootFounders020", dataOG.data.root);
    // const rootOG = await minterFounders.setRootFounders020(rootOg); // PRODUCTION
    // await rootOG.wait();
    // console.log("Setup -- minter.merkleRoot020: set merkle root to " + await minterFounders.rootFounders020());

    // const data025 = await axios.get(CONFIGURATION.merkleRoot025); 
    // console.log("rootFounders025", data025.data.root);
    // await waitFor(minterFounders.setRootFounders025(data025.data.root)); // PRODUCTION
    // console.log("Setup -- minter.merkleRoot025: set merkle root to " + await minterFounders.rootFounders025());

    // const dataWL2 = await axios.get(CONFIGURATION.merkleRootFreeKNFT);
    // console.log("rootFreeKNFT", dataWL2.data.root);  
    // await waitFor(minterFounders.setRootFreeKNFT(dataWL2.data.root)); // PRODUCTION
    // console.log("Setup -- minter.merkleRootFreeKNFT: set merkle root to " + await minterFounders.rootFreeKNFT());

    // // Step 4: Set initial price
    // await waitFor(minterFounders.setPriceFounders020(CONFIGURATION.initialPrice020)); // PRODUCTION
    // console.log("Setup -- minter.setPriceOG: set initial price to " + CONFIGURATION.initialPrice020);

    // await waitFor(minterFounders.setPriceFounders025(CONFIGURATION.initialPrice025)); // PRODUCTION
    // console.log("Setup -- minter.setPriceWL1: set initial price to " + CONFIGURATION.initialPrice025);

    // console.log(await minterFounders.rootFounders020());

    // // Step 5: Configure treasury
    await waitFor(authority.pushVault(treasuryDeployment.address, true)); // PRODUCTION
    console.log("Set treasury as vault");
    await waitFor(treasury.setPermission(0, minterFoundersDeployment.address, true)); // PRODUCTION
    console.log("Set minter founders as depositor");
    await waitFor(treasury.setPermission(0, minterPublicDeployment.address, true));
    console.log("Set minter public as depositor");
    await waitFor(treasury.setPermission(0, stakingDeployment.address, true));
    console.log("Set staking as depositor");
    await waitFor(treasury.setPermission(1, signerAddress, true));  // PRODUCTION
    console.log("Set deployer as spender");
    await waitFor(treasury.setPermission(0, signerAddress, true));  // setting deployer as depositor
    console.log("Set deployer as depositor");
    await waitFor(treasury.setPermission(1, stakingDeployment.address, true));
    console.log("Set staking as spender");
    await waitFor(treasury.setPermission(2, konduxERC20Deployment.address, true)); 
    console.log("Set konduxERC as reserve token");
    await waitFor(treasury.setStakingContract(stakingDeployment.address));
    console.log("Set staking contract");
    await waitFor(treasury.erc20ApprovalSetup(konduxERC20Deployment.address, ethers.BigNumber.from(10).pow(38)));
    console.log("Set Approval for konduxERC");

    // // Step 6: Configure helix
    await waitFor(helix.setAllowedContract(stakingDeployment.address, true));
    console.log("Set staking as allowed contract");
    await waitFor(helix.setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), stakingDeployment.address, true));
    console.log("Set staking as minter");
    await waitFor(helix.setRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("BURNER_ROLE")), stakingDeployment.address, true));
    console.log("Set staking as burner");

    // TESTING ONLY
    // await waitFor(konduxERC20.approve(treasuryDeployment.address, ethers.BigNumber.from(10).pow(28)));
    // console.log("Set Approval for konduxERC");
    // await waitFor(treasury.deposit(ethers.BigNumber.from(10).pow(28), konduxERC20Deployment.address));
    // console.log("Deposit konduxERC");
    // await waitFor(staking.setCompoundFreq(60, konduxERC20Deployment.address));
    // console.log("Set compound frequency to 60 seconds");
    // await waitFor(staking.setAPR(25, konduxERC20Deployment.address));
    // console.log("Set APR to 25%");
    // await waitFor(staking.setCompoundFreq(60 * , konduxERC20Deployment.address));
    // console.log("Set compound frequency to 60 seconds");
    // await waitFor(konduxERC20.enableTrading());
    // console.log("Enable trading for konduxERC");

};

func.tags = ["setup", "production"];

export default func;
