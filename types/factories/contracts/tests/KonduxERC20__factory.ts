/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  KonduxERC20,
  KonduxERC20Interface,
} from "../../../contracts/tests/KonduxERC20";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "subtractedValue",
        type: "uint256",
      },
    ],
    name: "decreaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "faucet",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "addedValue",
        type: "uint256",
      },
    ],
    name: "increaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60806040523480156200001157600080fd5b50604080518082018252600b8082526a04b6f6e64757845524332360ac1b60208084018281528551808701909652928552840152815191929162000058916003916200017c565b5080516200006e9060049060208401906200017c565b506200007c91505062000082565b62000286565b62000092336305f5e10062000094565b565b6001600160a01b038216620000ef5760405162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f206164647265737300604482015260640160405180910390fd5b806002600082825462000103919062000222565b90915550506001600160a01b038216600090815260208190526040812080548392906200013290849062000222565b90915550506040518181526001600160a01b038316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b8280546200018a9062000249565b90600052602060002090601f016020900481019282620001ae5760008555620001f9565b82601f10620001c957805160ff1916838001178555620001f9565b82800160010185558215620001f9579182015b82811115620001f9578251825591602001919060010190620001dc565b50620002079291506200020b565b5090565b5b808211156200020757600081556001016200020c565b600082198211156200024457634e487b7160e01b600052601160045260246000fd5b500190565b600181811c908216806200025e57607f821691505b602082108114156200028057634e487b7160e01b600052602260045260246000fd5b50919050565b610a1080620002966000396000f3fe608060405234801561001057600080fd5b50600436106100d45760003560e01c806370a0823111610081578063a9059cbb1161005b578063a9059cbb146101a5578063dd62ed3e146101b8578063de5f72fd146101f157600080fd5b806370a082311461016157806395d89b411461018a578063a457c2d71461019257600080fd5b806323b872dd116100b257806323b872dd1461012c578063313ce5671461013f578063395093511461014e57600080fd5b806306fdde03146100d9578063095ea7b3146100f757806318160ddd1461011a575b600080fd5b6100e16101fb565b6040516100ee9190610876565b60405180910390f35b61010a6101053660046108e7565b61028d565b60405190151581526020016100ee565b6002545b6040519081526020016100ee565b61010a61013a366004610911565b6102a5565b604051601281526020016100ee565b61010a61015c3660046108e7565b6102c9565b61011e61016f36600461094d565b6001600160a01b031660009081526020819052604090205490565b6100e1610308565b61010a6101a03660046108e7565b610317565b61010a6101b33660046108e7565b6103c6565b61011e6101c636600461096f565b6001600160a01b03918216600090815260016020908152604080832093909416825291909152205490565b6101f96103d4565b005b60606003805461020a906109a2565b80601f0160208091040260200160405190810160405280929190818152602001828054610236906109a2565b80156102835780601f1061025857610100808354040283529160200191610283565b820191906000526020600020905b81548152906001019060200180831161026657829003601f168201915b5050505050905090565b60003361029b8185856103e4565b5060019392505050565b6000336102b3858285610508565b6102be85858561059a565b506001949350505050565b3360008181526001602090815260408083206001600160a01b038716845290915281205490919061029b90829086906103039087906109dd565b6103e4565b60606004805461020a906109a2565b3360008181526001602090815260408083206001600160a01b0387168452909152812054909190838110156103b95760405162461bcd60e51b815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f00000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6102be82868684036103e4565b60003361029b81858561059a565b6103e2336305f5e100610797565b565b6001600160a01b0383166104465760405162461bcd60e51b8152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f206164646044820152637265737360e01b60648201526084016103b0565b6001600160a01b0382166104a75760405162461bcd60e51b815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f206164647265604482015261737360f01b60648201526084016103b0565b6001600160a01b0383811660008181526001602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925910160405180910390a3505050565b6001600160a01b03838116600090815260016020908152604080832093861683529290522054600019811461059457818110156105875760405162461bcd60e51b815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e636500000060448201526064016103b0565b61059484848484036103e4565b50505050565b6001600160a01b0383166106165760405162461bcd60e51b815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f647265737300000000000000000000000000000000000000000000000000000060648201526084016103b0565b6001600160a01b0382166106785760405162461bcd60e51b815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201526265737360e81b60648201526084016103b0565b6001600160a01b038316600090815260208190526040902054818110156107075760405162461bcd60e51b815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e6365000000000000000000000000000000000000000000000000000060648201526084016103b0565b6001600160a01b0380851660009081526020819052604080822085850390559185168152908120805484929061073e9084906109dd565b92505081905550826001600160a01b0316846001600160a01b03167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef8460405161078a91815260200190565b60405180910390a3610594565b6001600160a01b0382166107ed5760405162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f20616464726573730060448201526064016103b0565b80600260008282546107ff91906109dd565b90915550506001600160a01b0382166000908152602081905260408120805483929061082c9084906109dd565b90915550506040518181526001600160a01b038316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b600060208083528351808285015260005b818110156108a357858101830151858201604001528201610887565b818111156108b5576000604083870101525b50601f01601f1916929092016040019392505050565b80356001600160a01b03811681146108e257600080fd5b919050565b600080604083850312156108fa57600080fd5b610903836108cb565b946020939093013593505050565b60008060006060848603121561092657600080fd5b61092f846108cb565b925061093d602085016108cb565b9150604084013590509250925092565b60006020828403121561095f57600080fd5b610968826108cb565b9392505050565b6000806040838503121561098257600080fd5b61098b836108cb565b9150610999602084016108cb565b90509250929050565b600181811c908216806109b657607f821691505b602082108114156109d757634e487b7160e01b600052602260045260246000fd5b50919050565b600082198211156109fe57634e487b7160e01b600052601160045260246000fd5b50019056fea164736f6c6343000809000a";

type KonduxERC20ConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: KonduxERC20ConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class KonduxERC20__factory extends ContractFactory {
  constructor(...args: KonduxERC20ConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<KonduxERC20> {
    return super.deploy(overrides || {}) as Promise<KonduxERC20>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): KonduxERC20 {
    return super.attach(address) as KonduxERC20;
  }
  override connect(signer: Signer): KonduxERC20__factory {
    return super.connect(signer) as KonduxERC20__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): KonduxERC20Interface {
    return new utils.Interface(_abi) as KonduxERC20Interface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): KonduxERC20 {
    return new Contract(address, _abi, signerOrProvider) as KonduxERC20;
  }
}