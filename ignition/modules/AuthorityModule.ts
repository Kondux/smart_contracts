import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Authority", (m) => {
  const owner = m.getAccount(0);
  const authority = m.contract("Authority", [owner, owner, owner, owner]);

  // m.call(apollo, "launch", []);

  return { authority };
});