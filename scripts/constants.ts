export const CONTRACTS: Record<string, string> = {
  kondux: "Kondux",
  authority: "Authority",
  minter: "Minter",
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  erc721: "Kondux NFT",
  ticker: "KONDUX",
  baseURI: "https://kondux.com/", 
  initialPrice: "1" + "0".repeat(15), // in wei 
};