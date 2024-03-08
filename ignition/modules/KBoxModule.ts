import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("KBox", (m) => {

  const kBox = m.contract("KonduxERC721kNFT");

  // m.call(apollo, "launch", []);

  return { kBox }; 
});