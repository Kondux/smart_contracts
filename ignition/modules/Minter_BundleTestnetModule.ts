import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TreasuryModule from "./TreasuryModule";
import KNFTModule from "./KNFTModule";
import KBoxModule from "./KBoxModule";
import FoundersModule from "./FoundersModule";

export default buildModule("MinterBundleTestnet", (m) => {
  // const treasury = m.useModule(TreasuryModule);
  const treasury = m.contractAt("Treasury", "0x7Ac1B87116Df992a961Be2ccdd92dd9659f834ae");
  const knft = m.useModule(KNFTModule);
  // const kbox = m.useModule(KBoxModule);
  const kbox = m.contractAt("KBox", "0x71DE28127308b55f000CbDd3377Dc260Ce8C5d23");
  const founders = m.useModule(FoundersModule);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  // const minterBundle = m.contract("MinterBundle", [knft.kondux, kbox.kBox, founders.founders, treasury.treasury]);
  const minterBundle = m.contract("MinterBundle", [knft.kondux, kbox.address, founders.founders, treasury.address]);

  m.call(treasury, "setPermission", [0, minterBundle, true]);
  m.call(knft.kondux, "grantRole", [MINTER_ROLE, minterBundle]);

  const price = ethers.parseEther("0.00001"); 
  m.call(minterBundle, "setPrice", [price]);

  m.call(minterBundle, "setPaused", [false]);

  return { minterBundle }; 
});
