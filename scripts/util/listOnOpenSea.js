const { ethers } = require("ethers");
require("dotenv").config();

// Configuration - Contract addresses (public constants)
const COLLECTION = process.env.COLLECTION_ADDRESS || "0x167a45aaC7a4512089eC6d401547351d7c73e66F";
const SPLITTER = process.env.SPLITTER_ADDRESS || "0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8";
const SEAPORT = "0x0000000000000068F116a894984e2DB1123eB395";
const OPENSEA_FEE_RECIPIENT = "0x0000a26b00c1F0DF003000390027140000fAa719";
const OPENSEA_CONDUIT_KEY = "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000";

// CLI args or defaults
const TOKEN_ID = process.argv[2] ? parseInt(process.argv[2]) : 2;
const PRICE_ETH = process.argv[3] || "0.0001";

// Secrets from environment (required)
const SELLER_PK = process.env.PROD_TEST_PK;
const RPC_URL = process.env.MAINNET_RPC_URL;
const OPENSEA_API_KEY = process.env.OPENSEA_API_KEY;

// Validate required env vars
if (!SELLER_PK) throw new Error("PROD_TEST_PK environment variable required");
if (!RPC_URL) throw new Error("MAINNET_RPC_URL environment variable required");
if (!OPENSEA_API_KEY) throw new Error("OPENSEA_API_KEY environment variable required");

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(SELLER_PK, provider);
  const seller = wallet.address;

  console.log("Seller:", seller);
  console.log("Token ID:", TOKEN_ID);
  console.log("Collection:", COLLECTION);

  // Price calculations
  const priceWei = ethers.parseEther(PRICE_ETH);
  const openSeaFeeBP = 100n; // 1% (OpenSea current fee)
  const royaltyBP = 1000n; // 10%

  const openSeaFee = (priceWei * openSeaFeeBP) / 10000n;
  const royalty = (priceWei * royaltyBP) / 10000n;
  const sellerProceeds = priceWei - openSeaFee - royalty;

  console.log("Price:", PRICE_ETH, "ETH");
  console.log("OpenSea Fee (1%):", ethers.formatEther(openSeaFee), "ETH");
  console.log("Royalty (10%):", ethers.formatEther(royalty), "ETH");
  console.log("Seller Proceeds:", ethers.formatEther(sellerProceeds), "ETH");

  // Time parameters
  const startTime = Math.floor(Date.now() / 1000);
  const endTime = startTime + 30 * 24 * 60 * 60; // 30 days

  // Generate random salt
  const salt = ethers.hexlify(ethers.randomBytes(32));

  // Build order parameters
  const orderParameters = {
    offerer: seller,
    zone: "0x0000000000000000000000000000000000000000",
    offer: [
      {
        itemType: 2, // ERC721
        token: COLLECTION,
        identifierOrCriteria: TOKEN_ID.toString(),
        startAmount: "1",
        endAmount: "1"
      }
    ],
    consideration: [
      {
        itemType: 0, // ETH
        token: "0x0000000000000000000000000000000000000000",
        identifierOrCriteria: "0",
        startAmount: sellerProceeds.toString(),
        endAmount: sellerProceeds.toString(),
        recipient: seller
      },
      {
        itemType: 0, // ETH
        token: "0x0000000000000000000000000000000000000000",
        identifierOrCriteria: "0",
        startAmount: openSeaFee.toString(),
        endAmount: openSeaFee.toString(),
        recipient: OPENSEA_FEE_RECIPIENT
      },
      {
        itemType: 0, // ETH
        token: "0x0000000000000000000000000000000000000000",
        identifierOrCriteria: "0",
        startAmount: royalty.toString(),
        endAmount: royalty.toString(),
        recipient: SPLITTER
      }
    ],
    orderType: 0, // FULL_OPEN
    startTime: startTime.toString(),
    endTime: endTime.toString(),
    zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    salt: salt,
    conduitKey: OPENSEA_CONDUIT_KEY,
    counter: "0"
  };

  // EIP-712 domain
  const domain = {
    name: "Seaport",
    version: "1.6",
    chainId: 1,
    verifyingContract: SEAPORT
  };

  // EIP-712 types for Seaport OrderComponents
  const types = {
    OrderComponents: [
      { name: "offerer", type: "address" },
      { name: "zone", type: "address" },
      { name: "offer", type: "OfferItem[]" },
      { name: "consideration", type: "ConsiderationItem[]" },
      { name: "orderType", type: "uint8" },
      { name: "startTime", type: "uint256" },
      { name: "endTime", type: "uint256" },
      { name: "zoneHash", type: "bytes32" },
      { name: "salt", type: "uint256" },
      { name: "conduitKey", type: "bytes32" },
      { name: "counter", type: "uint256" }
    ],
    OfferItem: [
      { name: "itemType", type: "uint8" },
      { name: "token", type: "address" },
      { name: "identifierOrCriteria", type: "uint256" },
      { name: "startAmount", type: "uint256" },
      { name: "endAmount", type: "uint256" }
    ],
    ConsiderationItem: [
      { name: "itemType", type: "uint8" },
      { name: "token", type: "address" },
      { name: "identifierOrCriteria", type: "uint256" },
      { name: "startAmount", type: "uint256" },
      { name: "endAmount", type: "uint256" },
      { name: "recipient", type: "address" }
    ]
  };

  // Build message for signing
  const message = {
    offerer: orderParameters.offerer,
    zone: orderParameters.zone,
    offer: orderParameters.offer.map(item => ({
      itemType: item.itemType,
      token: item.token,
      identifierOrCriteria: item.identifierOrCriteria,
      startAmount: item.startAmount,
      endAmount: item.endAmount
    })),
    consideration: orderParameters.consideration.map(item => ({
      itemType: item.itemType,
      token: item.token,
      identifierOrCriteria: item.identifierOrCriteria,
      startAmount: item.startAmount,
      endAmount: item.endAmount,
      recipient: item.recipient
    })),
    orderType: orderParameters.orderType,
    startTime: orderParameters.startTime,
    endTime: orderParameters.endTime,
    zoneHash: orderParameters.zoneHash,
    salt: orderParameters.salt,
    conduitKey: orderParameters.conduitKey,
    counter: orderParameters.counter
  };

  console.log("\nSigning order...");
  const signature = await wallet.signTypedData(domain, types, message);
  console.log("Signature:", signature);

  // Build API payload
  const payload = {
    parameters: orderParameters,
    signature: signature,
    protocol_address: SEAPORT
  };

  console.log("\nSubmitting to OpenSea API...");
  console.log("Payload:", JSON.stringify(payload, null, 2));

  // Submit to OpenSea
  const response = await fetch("https://api.opensea.io/v2/orders/ethereum/seaport/listings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-KEY": OPENSEA_API_KEY
    },
    body: JSON.stringify(payload)
  });

  const result = await response.json();
  console.log("\nOpenSea Response:", JSON.stringify(result, null, 2));

  if (response.ok) {
    console.log("\nListing created successfully!");
    console.log("View on OpenSea: https://opensea.io/assets/ethereum/" + COLLECTION + "/" + TOKEN_ID);
  } else {
    console.log("\nError creating listing:", result);
  }
}

main().catch(console.error);
