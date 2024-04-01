import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Kondux_kNFT", (m) => {

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  const kondux = m.contract("Kondux",["Kondux kNFT", "KNFT"]);

  m.call(kondux, "setBaseURI", ["https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/"]);
  m.call(kondux, "grantRole", [MINTER_ROLE, "0xd81C688adDb82794c40611a2382bDE65F679c3D8"]);

  return { kondux }; 
});