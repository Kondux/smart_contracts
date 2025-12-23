const { ethers, network } = require("hardhat");
require("dotenv").config();

/**
 * This script does the following:
 * 1) Connects to a KonduxOracle contract already deployed on a given network.
 * 2) Generates random usage values, builds an inline JavaScript snippet for each usage,
 * 3) Calls requestUsageForUser() for a target user, logging the request IDs.
 * 4) Calls getUsage() to show the usage before fulfillment (which will still be old).
 * 
 * Note: The Chainlink Functions fulfillment occurs asynchronously (not immediate).
 *       So getUsage() right after the request won't yet reflect the updated usage 
 *       until the oracle's callback completes on-chain.
 */

async function main() {
  const networkName = network.name;
  console.log(`\nRunning script on network: ${networkName}`);

  // If the Oracle address is stored in .env, load it. Otherwise, paste directly here.
  // e.g. ORACLE_ADDRESS = "0xYourDeployedOracleHere"
  const oracleAddress = process.env.ORACLE_ADDRESS || "0x1234567890123456789012345678901234567890";
  if (oracleAddress === "0x1234567890123456789012345678901234567890") {
    throw new Error("Please set a valid ORACLE_ADDRESS in .env or in the script.");
  }

  // The user for whom we want to report usage
  // Typically, you'd have real user addresses or read them from a DB/CSV, etc.
  // For demonstration, we use the same address for all requests
  const targetUser = process.env.USER_ADDRESS || "0xabcdefABCDEFabcdefABCDEFabcdefABCDEFabcd";

  // Hard-coded chainlink functions parameters
  const subscriptionId = 4548;        // as given in your request
  const gasLimit = 100000;           // example max gas for the request
  const donId = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000"; // placeholder DON ID (job ID) - replace with real if needed
  // secretsUrlsOrSlot could be an empty bytes if you have no secrets
  const secretsUrlsOrSlot = "0x";     // or pass a reference if you have secrets

  // We'll make a few random usage requests
  const numberOfRequests = 3;

  // --- Connect to the deployed Oracle ---
  const [deployer] = await ethers.getSigners(); // or load a private key from .env
  console.log(`Deployer: ${deployer.address}\n`);

  const oracleContract = await ethers.getContractAt("KonduxOracle", oracleAddress, deployer);
  console.log(`Connected to KonduxOracle at: ${oracleContract.target}\n`);

  // Optionally check current usage for the user
  let currentUsage = await oracleContract.getUsage(targetUser);
  console.log(`Initial getUsage(${targetUser}): ${currentUsage.toString()}\n`);

  // For demonstration, we'll loop through multiple requests
  for (let i = 1; i <= numberOfRequests; i++) {
    // Generate a random usage (0-999). The off-chain script will return it as a string
    const randomUsage = Math.floor(Math.random() * 1000);

    // Build the inline JavaScript source code that returns randomUsage
    // Typically, you'd fetch from an external API, but here we just return a literal usage
    // as a string. The oracle's `_bytesToUint` will parse it on fulfillment.
    const source = `
      const usage = ${randomUsage};
      return Functions.encodeString(String(usage));
    `;

    // We can supply optional string args if we want, but not necessary for this example
    const args = [];
    const bytesArgs = [];

    console.log(`Request #${i}: Mock usage = ${randomUsage}`);
    console.log("Sending requestUsageForUser transaction...");

    console.log("Parameters:");
    console.log(`  targetUser: ${targetUser}`);
    console.log(`  source:     ${source}`);
    console.log(`  args:       ${args}`);
    console.log(`  bytesArgs:  ${bytesArgs}`);
    console.log(`  secretsUrlsOrSlot: ${secretsUrlsOrSlot}`);
    console.log(`  subscriptionId: ${subscriptionId}`);
    console.log(`  gasLimit:    ${gasLimit}`);
    console.log(`  donId:       ${donId}`);
    console.log("");

    // Make the request transaction
    const tx = await oracleContract.requestUsageForUser(
      targetUser,
      source,
      args,
      bytesArgs,
      secretsUrlsOrSlot,
      subscriptionId,
      gasLimit,
      donId
    );
    const receipt = await tx.wait();
    console.log(`  Tx hash: ${receipt.transactionHash}`);

    // Parse out the "RequestSent" event from logs
    const requestSentEvent = receipt.logs
      .map(log => {
        try {
          return oracleContract.interface.parseLog(log);
        } catch (e) {
          return null; // not an oracle event
        }
      })
      .filter(e => e && e.name === "RequestSent")[0];

    if (requestSentEvent) {
      const requestId = requestSentEvent.args.requestId;
      const user = requestSentEvent.args.user;
      console.log(`  Request ID: ${requestId}`);
      console.log(`  For user:   ${user}`);
    } else {
      console.warn("Could not parse RequestSent event from logs.");
    }

    console.log("");

    // Check usage immediately (will likely be unchanged due to asynchronous callback)
    currentUsage = await oracleContract.getUsage(targetUser);
    console.log(`getUsage(${targetUser}) immediately after request: ${currentUsage.toString()}\n`);
    console.log("--------------------------------------------------\n");
  }

  console.log(`All ${numberOfRequests} requests have been sent.\n`);
  console.log("NOTE: The usage on-chain will only update after Chainlink Functions");
  console.log("      performs the off-chain computation and calls fulfillRequest().\n");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("Script failed:", error);
    process.exit(1);
  });
