import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("KonduxDemo", (m) => {

  const konduxDemo = m.contract("KonduxDemo",["KonduxDemo", "KNDX_DEMO"]);

  return { konduxDemo }; 
});