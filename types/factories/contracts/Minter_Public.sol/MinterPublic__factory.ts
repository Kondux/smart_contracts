/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  MinterPublic,
  MinterPublicInterface,
} from "../../../contracts/Minter_Public.sol/MinterPublic";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_authority",
        type: "address",
      },
      {
        internalType: "address",
        name: "_konduxFounders",
        type: "address",
      },
      {
        internalType: "address",
        name: "_vault",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "contract IAuthority",
        name: "authority",
        type: "address",
      },
    ],
    name: "AuthorityUpdated",
    type: "event",
  },
  {
    inputs: [],
    name: "authority",
    outputs: [
      {
        internalType: "contract IAuthority",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "konduxFounders",
    outputs: [
      {
        internalType: "contract IKonduxFounders",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "price",
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
    name: "publicMint",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract IAuthority",
        name: "_newAuthority",
        type: "address",
      },
    ],
    name: "setAuthority",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_konduxFounders",
        type: "address",
      },
    ],
    name: "setKonduxFounders",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bool",
        name: "_paused",
        type: "bool",
      },
    ],
    name: "setPaused",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_treasury",
        type: "address",
      },
    ],
    name: "setTreasury",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "treasury",
    outputs: [
      {
        internalType: "contract ITreasury",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060405161099538038061099583398101604081905261002f91610201565b826001600160a01b03811661008b5760405162461bcd60e51b815260206004820181905260248201527f417574686f726974792063616e6e6f74206265207a65726f206164647265737360448201526064015b60405180910390fd5b600080546001600160a01b0319166001600160a01b0383169081179091556040519081527f2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad9060200160405180910390a1506001600160a01b0382166101335760405162461bcd60e51b815260206004820152601960248201527f4b6f6e6475782061646472657373206973206e6f7420736574000000000000006044820152606401610082565b600280546001600160a01b0380851661010002610100600160a81b03199092169190911790915581166101a85760405162461bcd60e51b815260206004820152601860248201527f5661756c742061646472657373206973206e6f742073657400000000000000006044820152606401610082565b600380546001600160a01b0319166001600160a01b039290921691909117905550506703782dace9d900006001556002805460ff19169055610244565b80516001600160a01b03811681146101fc57600080fd5b919050565b60008060006060848603121561021657600080fd5b61021f846101e5565b925061022d602085016101e5565b915061023b604085016101e5565b90509250925092565b610742806102536000396000f3fe6080604052600436106100bc5760003560e01c80637a9e5e4b11610074578063bf7e214f1161004e578063bf7e214f146101d6578063f0f44260146101f6578063fa3aa5091461021657600080fd5b80637a9e5e4b1461018057806391b7f5ed146101a0578063a035b1fe146101c057600080fd5b80633ca173ec116100a55780633ca173ec146100fe5780635c975abb1461011e57806361d027b31461014857600080fd5b806316c38b3c146100c157806326092b83146100e3575b600080fd5b3480156100cd57600080fd5b506100e16100dc366004610688565b61023b565b005b6100eb610256565b6040519081526020015b60405180910390f35b34801561010a57600080fd5b506100e16101193660046106c9565b610440565b34801561012a57600080fd5b506002546101389060ff1681565b60405190151581526020016100f5565b34801561015457600080fd5b50600354610168906001600160a01b031681565b6040516001600160a01b0390911681526020016100f5565b34801561018c57600080fd5b506100e161019b3660046106c9565b610487565b3480156101ac57600080fd5b506100e16101bb3660046106e6565b6104f0565b3480156101cc57600080fd5b506100eb60015481565b3480156101e257600080fd5b50600054610168906001600160a01b031681565b34801561020257600080fd5b506100e16102113660046106c9565b6104fd565b34801561022257600080fd5b506002546101689061010090046001600160a01b031681565b610243610534565b6002805460ff1916911515919091179055565b60025460009060ff16156102b15760405162461bcd60e51b815260206004820152601060248201527f5061757361626c653a207061757365640000000000000000000000000000000060448201526064015b60405180910390fd5b61028a600260019054906101000a90046001600160a01b03166001600160a01b03166318160ddd6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610307573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061032b91906106ff565b106103785760405162461bcd60e51b815260206004820152601160248201527f4e6f206d6f7265204e465473206c65667400000000000000000000000000000060448201526064016102a8565b6001543410156103ca5760405162461bcd60e51b815260206004820152601360248201527f4e6f7420656e6f756768204554482073656e740000000000000000000000000060448201526064016102a8565b600360009054906101000a90046001600160a01b03166001600160a01b03166398ea5fca346040518263ffffffff1660e01b81526004016000604051808303818588803b15801561041a57600080fd5b505af115801561042e573d6000803e3d6000fd5b505050505061043b61060b565b905090565b610448610534565b600280546001600160a01b03909216610100027fffffffffffffffffffffff0000000000000000000000000000000000000000ff909216919091179055565b61048f610534565b6000805473ffffffffffffffffffffffffffffffffffffffff19166001600160a01b0383169081179091556040519081527f2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad9060200160405180910390a150565b6104f8610534565b600155565b610505610534565b6003805473ffffffffffffffffffffffffffffffffffffffff19166001600160a01b0392909216919091179055565b60008054906101000a90046001600160a01b03166001600160a01b0316630c340a246040518163ffffffff1660e01b8152600401602060405180830381865afa158015610585573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105a99190610718565b6001600160a01b0316336001600160a01b0316146106095760405162461bcd60e51b815260206004820152600c60248201527f554e415554484f52495a4544000000000000000000000000000000000000000060448201526064016102a8565b565b6002546040516340d097c360e01b815233600482015260009182916101009091046001600160a01b0316906340d097c3906024016020604051808303816000875af115801561065e573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061068291906106ff565b92915050565b60006020828403121561069a57600080fd5b813580151581146106aa57600080fd5b9392505050565b6001600160a01b03811681146106c657600080fd5b50565b6000602082840312156106db57600080fd5b81356106aa816106b1565b6000602082840312156106f857600080fd5b5035919050565b60006020828403121561071157600080fd5b5051919050565b60006020828403121561072a57600080fd5b81516106aa816106b156fea164736f6c6343000810000a";

type MinterPublicConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: MinterPublicConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class MinterPublic__factory extends ContractFactory {
  constructor(...args: MinterPublicConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _authority: PromiseOrValue<string>,
    _konduxFounders: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<MinterPublic> {
    return super.deploy(
      _authority,
      _konduxFounders,
      _vault,
      overrides || {}
    ) as Promise<MinterPublic>;
  }
  override getDeployTransaction(
    _authority: PromiseOrValue<string>,
    _konduxFounders: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      _authority,
      _konduxFounders,
      _vault,
      overrides || {}
    );
  }
  override attach(address: string): MinterPublic {
    return super.attach(address) as MinterPublic;
  }
  override connect(signer: Signer): MinterPublic__factory {
    return super.connect(signer) as MinterPublic__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): MinterPublicInterface {
    return new utils.Interface(_abi) as MinterPublicInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): MinterPublic {
    return new Contract(address, _abi, signerOrProvider) as MinterPublic;
  }
}