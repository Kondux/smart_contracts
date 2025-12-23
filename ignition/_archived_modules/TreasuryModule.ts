import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import AuthorityModule from "./AuthorityModule";

export default buildModule("Treasury", (m) => {
  const authority = m.useModule(AuthorityModule);

  const treasury = m.contract("Treasury", [authority.authority]);

  // m.call(apollo, "launch", []);

  return { treasury }; 
});