import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import KNFTModule from "./KNFTModule";

export default buildModule("MinterBundle", (m) => {
  const treasury = m.contractAt("Treasury", "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E");
  const knft = m.useModule(KNFTModule);
  const kbox = m.contractAt("KBox", "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419");

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  const minterBundle = m.contract("MinterBundle", [knft.kondux, kbox.address, treasury.address]);

  m.call(treasury, "setPermission", [0, minterBundle, true]);
  m.call(knft.kondux, "grantRole", [MINTER_ROLE, minterBundle]);

  return { minterBundle }; 
});
