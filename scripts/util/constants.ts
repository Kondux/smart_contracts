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
  konduxERC721Founders: "KonduxERC721Founders",
  konduxERC721kNFT: "KonduxERC721kNFT",
  helix: "Helix",
  realKNDX_ERC20: "KNDX"
};

export const CONFIGURATION: Record<string, any> = {
  hardhatChainId: 1337,
  ethereumChainId: 1,
  sepoliaChainId: 11155111,
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
  helixName: "Helix",
  helixTicker: "HLX",

  // contracts
  authorityProduction: "0x6a005c11217863c4e300ce009c5ddc7e1672150a",
  authorityTestnet: "0x685a13093ca561f531c93185b942a3f33385e14e",
  konduxERC20Production: "0x7ca5af5ba3472af6049f63c1abc324475d44efc1",
  konduxERC20Testnet: "0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc",
  foundersERC721Production: "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
  foundersERC721Testnet: "0x434fD7FEEc752c4BfA4a59d0272c503ffD313499",
  kboxERC721Production: "0x7eD509A69F7FD93fD59A557369a9a5dCc1499685",
  kboxERC721Testnet: "0x434fD7FEEc752c4BfA4a59d0272c503ffD313499",
  minterPublicProduction: "0xDD6Dce66F11D2460B3b4A8Be8174749BC8d5e403",
  minterPublicTestnet: "0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc",
  minterFoundersProduction: "0x0fD5576c2842bD62dd00C5256491D11CcAD84306",
  minterFoundersTestnet: "0x434fD7FEEc752c4BfA4a59d0272c503ffD313499",
};