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
  minterPublic: "MinterPublic",
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  erc721: "Kondux NFT",
  ticker: "kNFT",
  erc721Founders: "Kondux Founders NFT",
  tickerFounders: "fKNDX",
  baseURIkNFTBox: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataBox/",
  baseURIFounders: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataFounders/", 
  initialPrice: "1" + "0".repeat(15), // in wei
  // 0.15 eth in wei
  initialPrice020: "200000000000000000", // in wei
  // 0.2 eth in wei
  initialPrice025: "250000000000000000", // in wei
  // 0.25 eth in wei
  initialPricePublic: "400000000000000000", // in wei
  merkleRootFreeFounders: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/rootFreeFounders",
  merkleRoot020: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/root020",
  merkleRoot025: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/root025",
  merkleRootFreeKNFT: "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/rootFreeKNFT", 
};