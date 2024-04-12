const { ethers } = require("ethers");
import { config as dotenvConfig } from "dotenv";
dotenvConfig({ path: resolve(__dirname, "../.env") });

const KBOX_ADDRESS = "0x7ed509a69f7fd93fd59a557369a9a5dcc1499685";
const MY_ALCHEMY_RPC_ENDPOINT='https://eth-mainnet.g.alchemy.com/v2/';

const KBOX_ABI = [
    "function safeMint(address to, uint256 tokenId)"
];

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const deployerPK = process.env.DEPLOYER_PK ?? "NO_DEPLOYER_PK"; 
const prodDeployerPK = process.env.PROD_DEPLOYER_PK ?? "NO_PROD_DEPLOYER_PK";

async function main() {
    // Configuration: Set up your provider and wallet
    const provider = new ethers.JsonRpcProvider(MY_ALCHEMY_RPC_ENDPOINT + ALCHEMY_API_KEY);
    const privateKey = deployerPK;
    const wallet = new ethers.Wallet(privateKey, provider);

    // Contract details
    const contractAddress = KBOX_ADDRESS;
    const contractABI = KBOX_ABI;
    const contract = new ethers.Contract(contractAddress, contractABI, wallet);

    // Read addresses from JSON file
    const data = await fs.readFile(resolve(__dirname, "./addresses.json"), "utf8");
    const addresses = JSON.parse(data);

    // Sending transactions with a 1 second pause between each
    for (const { address, count } of addresses) {
        for (let i = 0; i < count; i++) {
            try {
                const txResponse = await contract.safeMint(address, 0); // Assuming tokenId 0 is correct
                await txResponse.wait(); // Wait for the transaction to be mined
                console.log(`Minted to ${address} - #${i}, transaction hash: ${txResponse.hash}`);
            } catch (error) {
                console.error(`Error minting to ${address}: ${error}`);
            }
            await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for 1 second
        }
    }
}

main().catch(console.error);
