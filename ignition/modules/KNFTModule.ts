import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Kondux", (m) => {

  const kondux = m.contract("Kondux",["Kondux", "KNDX"]);

  // m.call(apollo, "launch", []);

  return { kondux }; 
});