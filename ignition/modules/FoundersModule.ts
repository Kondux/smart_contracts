import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("KonduxERC721Founders", (m) => {

  const founders = m.contract("KonduxERC721Founders");

  return { founders }; 
});