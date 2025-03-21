/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  MinterFounders,
  MinterFoundersInterface,
} from "../../../contracts/Minter_Founders.sol/MinterFounders";

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
        name: "_kondux",
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
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "founders020Claimed",
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
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "founders025Claimed",
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
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "freeFoundersClaimed",
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
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "freeKNFTClaimed",
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
    name: "kondux",
    outputs: [
      {
        internalType: "contract IKondux",
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
    name: "pausedFounders020",
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
    name: "pausedFounders025",
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
    name: "pausedFreeFounders",
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
    name: "pausedFreeKNFT",
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
    name: "pausedWhitelist",
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
    name: "priceFounders020",
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
    name: "priceFounders025",
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
    name: "priceFreeFounders",
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
    name: "priceFreeKNFT",
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
    name: "rootFounders020",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "rootFounders025",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "rootFreeFounders",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "rootFreeKNFT",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
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
    name: "setPausedFounders020",
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
    name: "setPausedFounders025",
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
    name: "setPausedFreeFounders",
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
    name: "setPausedFreeKNFT",
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
    name: "setPriceFounders020",
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
    name: "setPriceFounders025",
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
    name: "setPriceFreeFounders",
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
    name: "setPriceFreeKNFT",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "_rootFounders020",
        type: "bytes32",
      },
    ],
    name: "setRootFounders020",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "_rootFounders025",
        type: "bytes32",
      },
    ],
    name: "setRootFounders025",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "_rootFreeFounders",
        type: "bytes32",
      },
    ],
    name: "setRootFreeFounders",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "_rootFreeKNFT",
        type: "bytes32",
      },
    ],
    name: "setRootFreeKNFT",
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
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "_merkleProof",
        type: "bytes32[]",
      },
    ],
    name: "whitelistMintFounders020",
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
        internalType: "bytes32[]",
        name: "_merkleProof",
        type: "bytes32[]",
      },
    ],
    name: "whitelistMintFounders025",
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
        internalType: "bytes32[]",
        name: "_merkleProof",
        type: "bytes32[]",
      },
    ],
    name: "whitelistMintFreeFounders",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "_merkleProof",
        type: "bytes32[]",
      },
    ],
    name: "whitelistMintFreeKNFT",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60806040523480156200001157600080fd5b506040516200182d3803806200182d83398101604081905262000034916200027c565b836001600160a01b038116620000915760405162461bcd60e51b815260206004820181905260248201527f417574686f726974792063616e6e6f74206265207a65726f206164647265737360448201526064015b60405180910390fd5b600080546001600160a01b0319166001600160a01b0383169081179091556040519081527f2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad9060200160405180910390a1506001600160a01b0383166200013b5760405162461bcd60e51b815260206004820152601960248201527f4b6f6e6475782061646472657373206973206e6f742073657400000000000000604482015260640162000088565b600a80546001600160a01b0319166001600160a01b03858116919091179091558216620001ab5760405162461bcd60e51b815260206004820152601960248201527f4b6f6e6475782061646472657373206973206e6f742073657400000000000000604482015260640162000088565b600980546001600160a01b038085166501000000000002600160281b600160c81b0319909216919091179091558116620002285760405162461bcd60e51b815260206004820152601860248201527f5661756c742061646472657373206973206e6f74207365740000000000000000604482015260640162000088565b600b80546001600160a01b0319166001600160a01b039290921691909117905550506009805464ffffffff001916905550620002d9565b80516001600160a01b03811681146200027757600080fd5b919050565b600080600080608085870312156200029357600080fd5b6200029e856200025f565b9350620002ae602086016200025f565b9250620002be604086016200025f565b9150620002ce606086016200025f565b905092959194509250565b61154480620002e96000396000f3fe6080604052600436106102bb5760003560e01c80637a9e5e4b1161016e578063cb4abdbb116100cb578063f0f442601161007f578063f9aacab611610064578063f9aacab614610758578063fa3aa50914610778578063fb0d66aa1461079857600080fd5b8063f0f442601461071e578063f72ec8291461073e57600080fd5b8063cfe9f2be116100b0578063cfe9f2be146106d2578063d9c456c3146106e8578063d9d40bc2146106fe57600080fd5b8063cb4abdbb1461069c578063cc0eb867146106bc57600080fd5b8063b028a62411610122578063bf7e214f11610107578063bf7e214f14610666578063c7f6a1ee14610686578063cadff1ec146105d657600080fd5b8063b028a62414610616578063b56971f01461064657600080fd5b8063a236acf511610153578063a236acf5146105c0578063a78a1970146105d6578063ab389f34146105f657600080fd5b80637a9e5e4b146105805780638e017b86146105a057600080fd5b80636097b0981161021c5780636d8b8276116101d05780636ee25f4f116101b55780636ee25f4f1461052b57806375b080921461053e5780637778564e1461055e57600080fd5b80636d8b8276146104f85780636d8f759c1461051857600080fd5b8063632cdd0c11610201578063632cdd0c1461048957806369434b71146104b95780636b828a2d146104e257600080fd5b80636097b0981461043157806361d027b31461045157600080fd5b80633e15c0e61161027357806353a7af501161025857806353a7af50146103d25780635583cad2146103f15780636051df2a1461041157600080fd5b80633e15c0e61461038c5780634e6c6fe9146103a257600080fd5b806329b03082116102a457806329b030821461030b5780633ca173ec1461034b5780633d2c242a1461036b57600080fd5b80630fc461cc146102c057806326172bb1146102e9575b600080fd5b3480156102cc57600080fd5b506102d660055481565b6040519081526020015b60405180910390f35b3480156102f557600080fd5b506103096103043660046113e2565b6107b8565b005b34801561031757600080fd5b5061033b610326366004611419565b600d6020526000908152604090205460ff1681565b60405190151581526020016102e0565b34801561035757600080fd5b50610309610366366004611419565b6107e0565b34801561037757600080fd5b5060095461033b906301000000900460ff1681565b34801561039857600080fd5b506102d660085481565b3480156103ae57600080fd5b5061033b6103bd366004611419565b600e6020526000908152604090205460ff1681565b3480156103de57600080fd5b5060095461033b90610100900460ff1681565b3480156103fd57600080fd5b5061030961040c366004611436565b610817565b34801561041d57600080fd5b5061030961042c366004611436565b61082d565b34801561043d57600080fd5b5061030961044c366004611436565b61083a565b34801561045d57600080fd5b50600b54610471906001600160a01b031681565b6040516001600160a01b0390911681526020016102e0565b34801561049557600080fd5b5061033b6104a4366004611419565b600f6020526000908152604090205460ff1681565b3480156104c557600080fd5b50600954610471906501000000000090046001600160a01b031681565b3480156104ee57600080fd5b506102d660035481565b34801561050457600080fd5b506103096105133660046113e2565b610847565b6102d661052636600461144f565b610869565b6102d661053936600461144f565b610abf565b34801561054a57600080fd5b5060095461033b9062010000900460ff1681565b34801561056a57600080fd5b5060095461033b90640100000000900460ff1681565b34801561058c57600080fd5b5061030961059b366004611419565b610d09565b3480156105ac57600080fd5b506103096105bb366004611436565b610d72565b3480156105cc57600080fd5b506102d660065481565b3480156105e257600080fd5b506103096105f1366004611436565b610d7f565b34801561060257600080fd5b50610309610611366004611436565b610d8c565b34801561062257600080fd5b5061033b610631366004611419565b600c6020526000908152604090205460ff1681565b34801561065257600080fd5b506102d661066136600461144f565b610d99565b34801561067257600080fd5b50600054610471906001600160a01b031681565b34801561069257600080fd5b506102d660025481565b3480156106a857600080fd5b506103096106b73660046113e2565b610f22565b3480156106c857600080fd5b506102d660045481565b3480156106de57600080fd5b506102d660015481565b3480156106f457600080fd5b506102d660075481565b34801561070a57600080fd5b506102d661071936600461144f565b610f46565b34801561072a57600080fd5b50610309610739366004611419565b6110d0565b34801561074a57600080fd5b5060095461033b9060ff1681565b34801561076457600080fd5b506103096107733660046113e2565b611107565b34801561078457600080fd5b50600a54610471906001600160a01b031681565b3480156107a457600080fd5b506103096107b3366004611436565b61112d565b6107c061113a565b600980549115156401000000000264ff0000000019909216919091179055565b6107e861113a565b600a805473ffffffffffffffffffffffffffffffffffffffff19166001600160a01b0392909216919091179055565b61081f61113a565b61082881611211565b600655565b61083561113a565b600555565b61084261113a565b600855565b61084f61113a565b600980549115156101000261ff0019909216919091179055565b600954600090610100900460ff16156108c95760405162461bcd60e51b815260206004820152601e60248201527f466f756e6465727320303230206d696e74696e6720697320706175736564000060448201526064015b60405180910390fd5b60015434101561091b5760405162461bcd60e51b815260206004820152601160248201527f4e6f7420656e6f7567687420657468657200000000000000000000000000000060448201526064016108c0565b336000908152600c602052604090205460ff161561096d5760405162461bcd60e51b815260206004820152600f60248201526e105b1c9958591e4818db185a5b5959608a1b60448201526064016108c0565b600b60009054906101000a90046001600160a01b03166001600160a01b03166398ea5fca346040518263ffffffff1660e01b81526004016000604051808303818588803b1580156109bd57600080fd5b505af11580156109d1573d6000803e3d6000fd5b50506040516bffffffffffffffffffffffff193360601b1660208201526000935060340191506109fe9050565b604051602081830303815290604052805190602001209050610a5784848080602002602001604051908101604052809392919081815260200183836020028082843760009201919091525050600654915084905061126e565b610a955760405162461bcd60e51b815260206004820152600f60248201526e24b731b7b93932b1ba10383937b7b360891b60448201526064016108c0565b336000908152600c60205260409020805460ff19166001179055610ab7611284565b949350505050565b60095460009062010000900460ff1615610b1b5760405162461bcd60e51b815260206004820152601e60248201527f466f756e6465727320303235206d696e74696e6720697320706175736564000060448201526064016108c0565b600254341015610b6d5760405162461bcd60e51b815260206004820152601160248201527f4e6f7420656e6f7567687420657468657200000000000000000000000000000060448201526064016108c0565b336000908152600d602052604090205460ff1615610bbf5760405162461bcd60e51b815260206004820152600f60248201526e105b1c9958591e4818db185a5b5959608a1b60448201526064016108c0565b600b60009054906101000a90046001600160a01b03166001600160a01b03166398ea5fca346040518263ffffffff1660e01b81526004016000604051808303818588803b158015610c0f57600080fd5b505af1158015610c23573d6000803e3d6000fd5b50506040516bffffffffffffffffffffffff193360601b166020820152600093506034019150610c509050565b604051602081830303815290604052805190602001209050610ca984848080602002602001604051908101604052809392919081815260200183836020028082843760009201919091525050600754915084905061126e565b610ce75760405162461bcd60e51b815260206004820152600f60248201526e24b731b7b93932b1ba10383937b7b360891b60448201526064016108c0565b336000908152600d60205260409020805460ff19166001179055610ab7611284565b610d1161113a565b6000805473ffffffffffffffffffffffffffffffffffffffff19166001600160a01b0383169081179091556040519081527f2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad9060200160405180910390a150565b610d7a61113a565b600755565b610d8761113a565b600355565b610d9461113a565b600255565b6009546000906301000000900460ff1615610df65760405162461bcd60e51b815260206004820152601f60248201527f4672656520466f756e64657273206d696e74696e67206973207061757365640060448201526064016108c0565b336000908152600e602052604090205460ff1615610e485760405162461bcd60e51b815260206004820152600f60248201526e105b1c9958591e4818db185a5b5959608a1b60448201526064016108c0565b6040516bffffffffffffffffffffffff193360601b166020820152600090603401604051602081830303815290604052805190602001209050610ec284848080602002602001604051908101604052809392919081815260200183836020028082843760009201919091525050600554915084905061126e565b610f005760405162461bcd60e51b815260206004820152600f60248201526e24b731b7b93932b1ba10383937b7b360891b60448201526064016108c0565b336000908152600e60205260409020805460ff19166001179055610ab7611284565b610f2a61113a565b60098054911515620100000262ff000019909216919091179055565b600954600090640100000000900460ff1615610fa45760405162461bcd60e51b815260206004820152601b60248201527f46726565204b4e4654206d696e74696e6720697320706175736564000000000060448201526064016108c0565b336000908152600f602052604090205460ff1615610ff65760405162461bcd60e51b815260206004820152600f60248201526e105b1c9958591e4818db185a5b5959608a1b60448201526064016108c0565b6040516bffffffffffffffffffffffff193360601b16602082015260009060340160405160208183030381529060405280519060200120905061107084848080602002602001604051908101604052809392919081815260200183836020028082843760009201919091525050600854915084905061126e565b6110ae5760405162461bcd60e51b815260206004820152600f60248201526e24b731b7b93932b1ba10383937b7b360891b60448201526064016108c0565b336000908152600f60205260409020805460ff19166001179055610ab76112fe565b6110d861113a565b600b805473ffffffffffffffffffffffffffffffffffffffff19166001600160a01b0392909216919091179055565b61110f61113a565b6009805491151563010000000263ff00000019909216919091179055565b61113561113a565b600155565b60008054906101000a90046001600160a01b03166001600160a01b0316630c340a246040518163ffffffff1660e01b8152600401602060405180830381865afa15801561118b573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906111af91906114c4565b6001600160a01b0316336001600160a01b03161461120f5760405162461bcd60e51b815260206004820152600c60248201527f554e415554484f52495a4544000000000000000000000000000000000000000060448201526064016108c0565b565b61126b8160405160240161122791815260200190565b60408051601f198184030181529190526020810180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff166327b7cf8560e01b179052611342565b50565b60008261127b8584611363565b14949350505050565b600a546040516340d097c360e01b815233600482015260009182916001600160a01b03909116906340d097c3906024015b6020604051808303816000875af11580156112d4573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906112f891906114e1565b92915050565b600954604051632851206560e21b8152336004820152600060248201819052918291650100000000009091046001600160a01b03169063a1448194906044016112b5565b80516a636f6e736f6c652e6c6f67602083016000808483855afa5050505050565b600081815b84518110156113a85761139482868381518110611387576113876114fa565b60200260200101516113b0565b9150806113a081611510565b915050611368565b509392505050565b60008183106113cc5760008281526020849052604090206113db565b60008381526020839052604090205b9392505050565b6000602082840312156113f457600080fd5b813580151581146113db57600080fd5b6001600160a01b038116811461126b57600080fd5b60006020828403121561142b57600080fd5b81356113db81611404565b60006020828403121561144857600080fd5b5035919050565b6000806020838503121561146257600080fd5b823567ffffffffffffffff8082111561147a57600080fd5b818501915085601f83011261148e57600080fd5b81358181111561149d57600080fd5b8660208260051b85010111156114b257600080fd5b60209290920196919550909350505050565b6000602082840312156114d657600080fd5b81516113db81611404565b6000602082840312156114f357600080fd5b5051919050565b634e487b7160e01b600052603260045260246000fd5b60006001820161153057634e487b7160e01b600052601160045260246000fd5b506001019056fea164736f6c6343000811000a";

type MinterFoundersConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: MinterFoundersConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class MinterFounders__factory extends ContractFactory {
  constructor(...args: MinterFoundersConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _authority: PromiseOrValue<string>,
    _konduxFounders: PromiseOrValue<string>,
    _kondux: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<MinterFounders> {
    return super.deploy(
      _authority,
      _konduxFounders,
      _kondux,
      _vault,
      overrides || {}
    ) as Promise<MinterFounders>;
  }
  override getDeployTransaction(
    _authority: PromiseOrValue<string>,
    _konduxFounders: PromiseOrValue<string>,
    _kondux: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      _authority,
      _konduxFounders,
      _kondux,
      _vault,
      overrides || {}
    );
  }
  override attach(address: string): MinterFounders {
    return super.attach(address) as MinterFounders;
  }
  override connect(signer: Signer): MinterFounders__factory {
    return super.connect(signer) as MinterFounders__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): MinterFoundersInterface {
    return new utils.Interface(_abi) as MinterFoundersInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): MinterFounders {
    return new Contract(address, _abi, signerOrProvider) as MinterFounders;
  }
}
