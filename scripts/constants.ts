export const CONTRACTS: Record<string, string> = {
  kondux: "Kondux",
  authority: "Authority",
  minter: "Minter",
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  erc721: "Kondux NFT",
  ticker: "KONDUX",
  baseURI: "https://metadata.kondux.io/v1/", 
  initialPrice: "1" + "0".repeat(15), // in wei
  merkleRoot: "0x09d6d1856fc7fe679bc4ba95045ff67408d0bb274594180f0afffa6f46e5132d", 
};