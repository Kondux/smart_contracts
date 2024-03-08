import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TreasuryModule from "./TreasuryModule";
import KNFTModule from "./KNFTModule";
import KBoxModule from "./KBoxModule";


export default buildModule("MinterBundle", (m) => {
  const treasury = m.useModule(TreasuryModule);
  const knft = m.useModule(KNFTModule);
  const kbox = m.useModule(KBoxModule);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  const minterBundle = m.contract("MinterBundle", [knft.kondux, kbox.kBox, treasury.treasury]);

  m.call(treasury.treasury, "setPermission", [0, minterBundle, true]);
  m.call(knft.kondux, "grantRole", [MINTER_ROLE, minterBundle]);

  return { minterBundle }; 
});