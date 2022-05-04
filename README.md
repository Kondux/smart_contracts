# Kondux Contracts 
![image](https://avatars.githubusercontent.com/u/85846911?s=200&v=4)

This is the main Kondux smart contract development repository.

## 🔧 Setting up local development

### Requirements

- [Node v16](https://nodejs.org/download/release/latest-v16.x/)  
- [Git](https://git-scm.com/downloads)

### Local Setup Steps

```sh
# Clone the repository
git clone https://github.com/Kondux/smart_contracts.git

# Install dependencies
npm install

# Set up environment variables (keys)
cp .env.example .env # (linux)
copy .env.example .env # (windows)

### Hardhat usage:
## Just Compile: 
npx hardhat compile

## Deploy locally: 
# Dry deployment: 
npx hardhat deploy

# With node running:
npx hardhat node

# Connect with console:
npx hardhat console --network localhost

## Compile and Deploy to Rinkeby:
npx hardhat deploy --network rinkeby

## Test: 
npx hardhat test

# Generate typescript files
npx hardhat typechain

# Clean artifacts (doesn't need to be versioned):
npx hardhat clean
```

### Notes for `localhost`
-   The `deployments/localhost` directory is included in the git repository,
    so that the contract addresses remain constant. Otherwise, the frontend's
    `constants.ts` file would need to be updated.
-   Avoid committing changes to the `deployments/localhost` files (unless you
    are sure), as this will alter the state of the hardhat node when deployed
    in tests.

## 📖 Guides

### Whitelist Minting
1. Get the user's address from the frontend with Metamask

2. Send to Merkle Proof Server
   
[https://h7af1y611a.execute-api.us-east-1.amazonaws.com/:address/proof](https://h7af1y611a.execute-api.us-east-1.amazonaws.com/0x7c1b53c6e9fecd6112a3b156457ac6aba1135f82/proof)

    Return: Proof is a JSON object with the array of proofs

1. Get the Merkle Proof Array from the server and send to the contract
```
contract.whitelistMint(proof)
```

### Contracts
- [Rinkeby Addresses](./docs/deployments/rinkeby.md)

### Documentation
- [Kondux DAO](./docs/deployments/kondux_dao.md)
- [Kondux NFT DNA](./docs/guides/nft_dna.md)
- [Royalty Reward](./docs/guides/royalty_reward.md)
