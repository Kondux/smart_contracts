# Kondux Contracts 
[![Kondux Smart Contracts CI](https://github.com/Kondux/smart_contracts/actions/workflows/node.js.yml/badge.svg)](https://github.com/Kondux/smart_contracts/actions/workflows/node.js.yml)

![image](https://avatars.githubusercontent.com/u/85846911?s=200&v=4)

Kondux is a powerful and versatile smart contract system built on the Ethereum blockchain. It is designed to facilitate the creation, management, and monetization of NFTs, incorporating features such as royalties and access control. The smart contract leverages popular open-source libraries from the OpenZeppelin project and uses Hardhat for development, testing, and deployment.

Staking enables users to stake tokens and earn rewards. It includes features such as time-locked staking and rewards compounding. The contract is built with Solidity and uses OpenZeppelin library for standard interfaces and utilities.

## Key Features
- ERC-721 compliant NFT creation and management
- Extensible with ERC-721 Enumerable, Pausable, Burnable, and Royalty features
- Customizable royalty and access control mechanisms
- Events for tracking important contract actions
- Integration with Hardhat for a streamlined development experience
## Staking Features
- Staking: Users can stake their tokens to participate in the rewards program.
- Time-lock: Users can choose different time-lock durations for their stakes, which affects the rewards earned.
- Rewards Calculation: Rewards are calculated based on the staked amount, the time passed, and any applicable reward boosts.
- Reward Boosts: There are reward boosts for founders and kNFT holders that increase the rewards earned.
- Compound Rewards: Users can compound their rewards, allowing them to earn interest on their earned rewards.
- Claim Rewards: Users can claim their earned rewards at any time after the time-lock period has passed.
- Withdraw Stakes: Users can withdraw their staked tokens after the time-lock period has passed.

The Staking smart contract is built on top of the AccessControlled contract and includes several mappings to keep track of user deposits and rewards. The contract makes use of external interfaces such as IHelix, IERC20, IERC721, and ITreasury to interact with other components of the system.

## Vision
To be the leading provider of custom-fit SaaS solutions for artists, brands, and manufacturers, driving innovation in the realms of blockchain technology, NFTs, 3D marketplaces, AR/VR/XR environments, metaverse design, and gaming experiences.

## Mission
Our mission is to create custom-fit SaaS solutions by combining advanced API pipelines with secured technologies. We bridge creativity and blockchain technology together with NFTs, 3D NFT Marketplaces, AR/VR/XR Environments, Metaverse Design, Manufacturing Models, and Gaming Experiences.

## Community Values
- Innovation: We are committed to pushing the boundaries of technology and creativity to deliver cutting-edge solutions to our clients.
- Collaboration: We foster a culture of teamwork and open communication, believing that great ideas emerge from diverse perspectives.
- Quality: We are dedicated to providing high-quality, reliable, and secure solutions that meet and exceed our clients' expectations.
- Trust: We build trust by prioritizing security, transparency, and accountability in all our business practices.
- Empowerment: We support and empower artists, brands, and manufacturers to achieve their goals and realize their visions through our technology solutions.

## Licensing Strategy
Kondux's software and services are provided under a proprietary license, with specific licensing terms tailored to each client's needs. This approach ensures that we maintain the necessary control and flexibility to protect our intellectual property while providing clients with the customized solutions they require.

## Code of Conduct
We are committed to fostering a welcoming and inclusive community. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) for more information.

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
- [Kondux DAO](./docs/guides/kondux_dao.md)
- [Kondux NFT DNA](./docs/guides/nft_dna.md)
- [Royalty Reward](./docs/guides/royalty_reward.md)
- [Staking](./docs/guides/staking.md)