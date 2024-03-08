import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import KNFTModule from "./KNFTModule";
import Minter_BundleModule from "./Minter_BundleModule";
// import ethers from "ethers";

export default buildModule("MinterBundleTestnet", (m) => {  
  const knft = m.useModule(KNFTModule);
  const minterBundle = m.useModule(Minter_BundleModule);

  const price = ethers.parseEther("0.00001");
  console.log(price);
  
  m.call(minterBundle.minterBundle, "setPrice", [price]);
  
  return minterBundle; 
});