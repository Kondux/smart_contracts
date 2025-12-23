import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import KNFTModule from "./KNFTModule";
import axios from "axios";

const BASE_URL = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/";

export default buildModule("MinterBundle", (m) => {
  const treasury = m.contractAt("Treasury", "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E");
  const knft = m.useModule(KNFTModule);
  const kbox = m.contractAt("KBox", "0x7eD509A69F7FD93fD59A557369a9a5dCc1499685");
  const founders = m.contractAt("KonduxFounders", "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b");

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  const minterBundle = m.contract("MinterBundle", [knft.kondux, kbox.address, founders.address, treasury.address]);

  m.call(treasury, "setPermission", [0, minterBundle, true]);
  m.call(knft.kondux, "grantRole", [MINTER_ROLE, minterBundle]);

  axios.get(BASE_URL + "rootWhitelistBundle").then((res) => {
    const rootWhitelistBundle = res.data.root;
    m.call(minterBundle, "setWhitelistRoot", [rootWhitelistBundle]);
  });

  return { minterBundle }; 
});
