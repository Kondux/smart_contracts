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
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  erc721: "Kondux NFT",
  ticker: "KONDUX",
  baseURI: "https://metadata.kondux.io/v1/", 
  initialPrice: "1" + "0".repeat(15), // in wei
  merkleRoot: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/root", 
};