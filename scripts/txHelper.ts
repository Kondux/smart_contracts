import { ContractReceipt, ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { utils, BigNumber } from "ethers";
import axios from "axios";

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const https = require('https');
const httpsAgent = new https.Agent({ rejectUnauthorized: false });


export async function waitFor(txPromise: Promise<ContractTransaction>): Promise<ContractReceipt> {
    return await txPromise.then((tx) => tx.wait());
}

export async function getGasPrice(provider: JsonRpcProvider, account: string) {
    const network = await provider.getNetwork();
    let nonce = await provider.getTransactionCount(account);

    const gasStation = getGasStation(network.chainId);

    if (gasStation === "NONE") {
        return {};
    } else {
        const feeDataRequest = await axios.get(gasStation, { httpsAgent: httpsAgent });
    
        const feeData = await feeDataRequest.data;

        let overrides;

        if (feeData.blockNumber != null) {
            overrides = {
                type: 2,
                nonce: BigNumber.from(nonce),
                maxPriorityFeePerGas: utils.parseUnits("" + feeData.fast.maxPriorityFee.toFixed(9), 'gwei'),
                maxFeePerGas: utils.parseUnits("" + feeData.fast.maxFee.toFixed(9), 'gwei'),
                gasLimit: BigNumber.from("300000"),
            };
        } else {
            overrides = {};
        }

        return overrides;
    }
}

function getGasStation(chainId: number) {
    switch (chainId) {
        case 80001:
            return "https://gasstation-mumbai.matic.today/v2/";
        case 137:
            return "https://gasstation-mainnet.matic.network/v2/";
        // case rinkeby
        case 4:
            return "https://ethgasstation.info/json/ethgasAPI.json";
        default:
            return "NONE";
    }
}

function parse(ethers: any, data: any) {
    return ethers.utils.parseUnits(Math.ceil(data) + '', 'gwei');
}

export async function calcGas(ethers: any, gasEstimated: any) { 
    let gas = {
        gasLimit: gasEstimated.mul(120).div(100),
        maxFeePerGas: ethers.BigNumber.from(40000000000),
        maxPriorityFeePerGas: ethers.BigNumber.from(40000000000)
    };
    try {
        const { data } = await axios({
            method: 'get',
            url: 'https://gasstation-mumbai.matic.today/v2'
        });
        gas.maxFeePerGas = parse(ethers, data.fast.maxFee);
        gas.maxPriorityFeePerGas = parse(ethers, data.fast.maxPriorityFee);
    } catch (error) {

    }
    return gas;
};