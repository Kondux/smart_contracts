export const CONTRACTS: Record<string, string> = {
  kondux: "Kondux",
  authority: "Authority",
  minter: "Minter",
  marketplace: "Marketplace",
  konduxMarketplace: "KonduxMarketplace",
  staking: "Staking",
  konduxERC20: "KonduxERC20",
  konduxERC721: "KonduxERC721",
  konduxERC1155: "KonduxERC1155",
  treasury: "Treasury",
  konduxFounders: "KonduxFounders",
  minterFounders: "MinterFounders",
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  erc721: "Kondux NFT",
  ticker: "KONDUX",
  erc721Founders: "Kondux Founders NFT",
  tickerFounders: "fKNDX",
  baseURI: "https://metadata.kondux.io/v1/", 
  initialPrice: "1" + "0".repeat(15), // in wei
  // 0.15 eth in wei
  initialPriceOG: "15" + "0".repeat(16), // in wei
  // 0.2 eth in wei
  initialPriceWL1: "2" + "0".repeat(17), // in wei
  // 0.25 eth in wei
  initialPricePublic: "25" + "0".repeat(16), // in wei
  merkleRoot: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/root",
  merkleRootOG: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/rootOG",
  merkleRootWL1: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/rootWL1",
  merkleRootWL2: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/rootWL2", 
};