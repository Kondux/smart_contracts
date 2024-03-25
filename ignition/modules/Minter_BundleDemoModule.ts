import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import KNFTModuleDemo from "./KNFTModuleDemo";

export default buildModule("MinterBundleDemo", (m) => {
  const treasury = m.contractAt("Treasury", "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E");
  const knftDemo = m.useModule(KNFTModuleDemo);
  const kbox = m.contractAt("KBox", "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419");
  const founders = m.contractAt("KonduxFounders", "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b");

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  const minterBundleDemo = m.contract("MinterBundleDemo", [knftDemo.konduxDemo, kbox.address, founders.address, treasury.address]);

  m.call(treasury, "setPermission", [0, minterBundleDemo, true]);
  m.call(knftDemo.konduxDemo, "grantRole", [MINTER_ROLE, minterBundleDemo]);

  return { minterBundleDemo }; 
});
