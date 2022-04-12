import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@openzeppelin/hardhat-upgrades";

import "hardhat-deploy";

import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import { NetworkUserConfig } from "hardhat/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });


const DATAHUB_API_KEY = process.env.DATAHUB_API_KEY;
const FUJI_PRIVATE_KEY = process.env.FUJI_PRIVATE_KEY;
const ALCHEMY_API_KEY = "91XJqsiTl71uJgk19MlCHf0cc1leGk6a";
process.env.ALCHEMY_API_KEY = ALCHEMY_API_KEY;

const chainIds = {
    goerli: 5,
    hardhat: 1337,
    kovan: 42,
    mainnet: 1,
    rinkeby: 4,
    ropsten: 3,
};


// Ensure that we have all the environment variables we need.
const privateKey = process.env.PRIVATE_KEY ?? "NO_PRIVATE_KEY";
// Make sure node is setup on Alchemy website
const alchemyApiKey = process.env.ALCHEMY_API_KEY ?? "NO_ALCHEMY_API_KEY";


const chainIds = {
  goerli: 5,
  hardhat: 1337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
};

// Ensure that we have all the environment variables we need.
const privateKey = process.env.PRIVATE_KEY ?? "NO_PRIVATE_KEY";
// Make sure node is setup on Alchemy website
const alchemyApiKey = process.env.ALCHEMY_API_KEY ?? "NO_ALCHEMY_API_KEY";

function getChainConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const url = `https://eth-${network}.alchemyapi.io/v2/${alchemyApiKey}`;
  return {
      accounts: [`${privateKey}`],
      chainId: chainIds[network],
      url,
  };
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
    networks: {
      localhost: {
        url: "http://127.0.0.1:8545"
      },        
      hardhat: {
          mining: {
          //   auto: false,
          //   interval: 20000
          },
          chainId: chainIds.hardhat,
          loggingEnabled: true,
      },
      fuji: {
          url: `https://avalanche--fuji--rpc.datahub.figment.io/apikey/${DATAHUB_API_KEY}/ext/bc/C/rpc`,
          accounts: [`0x${FUJI_PRIVATE_KEY}`],
          gasPrice: 25000000000, //225000000000
                                // 25000000000
          // gas: 10001,
          // chainId: 43113,
        },
      avalanche: {
          url: `https://avalanche--mainnet--rpc.datahub.figment.io/apikey/${DATAHUB_API_KEY}/ext/bc/C/rpc`,
          accounts: [`0x${FUJI_PRIVATE_KEY}`],
          gasPrice: 25000000000,
        },
    // Uncomment for testing. Commented due to CI issues
    // mainnet: getChainConfig("mainnet"),
    // rinkeby: getChainConfig("rinkeby"),
    // ropsten: getChainConfig("ropsten"),
        rinkeby: {
          url: `https://eth-rinkeby.alchemyapi.io/v2/91XJqsiTl71uJgk19MlCHf0cc1leGk6a`,
          accounts: [`866bca934f155db9b85212aa4da23ef46fbf8e0765955d57b7107d866d95b907`, `eed89c1253297f07543b663bddc703acc96ff4932346d5d02965bd90364e4aef`],
          gas: 2100000,
          gasPrice: 8000000000,
        }
  },
  gasReporter: {
    currency: 'USD',
    token: 'ETH',
    gasPrice: 156,
    showMethodSig: true,
    showTimeSpent: true,
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },

  etherscan: {
    apiKey: "1PNB37Z8H8WNW4BBN6KRQU1TB6YJ66ZXIY"
  },

  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
};
