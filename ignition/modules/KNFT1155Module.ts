import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Kondux1155", (m) => {

  const kondux1155 = m.contract("Kondux1155");

  return { kondux1155 }; 
});