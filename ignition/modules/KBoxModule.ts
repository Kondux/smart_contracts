import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import AuthorityModule from "./AuthorityModule";

export default buildModule("KBox", (m) => {

  const authority = m.useModule(AuthorityModule);

  const kBox = m.contract("KBox", ["KBox", "KBOX", authority.authority]);

  return { kBox }; 
});