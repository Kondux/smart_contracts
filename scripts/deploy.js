const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
    const [deployer] = await ethers.getSigners();

    const signerAddress = "0xA399EE9198618a7faaCCE20bd3984e7D59FAe215"

    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const Token = await ethers.getContractFactory("Kondux");
    const token = await Token.connect(deployer).deploy("Kondux NFT", "KONDUX", signerAddress);
  
    console.log("verify address:", token.address);

    try {
        fs.writeFileSync('./artifacts/verify_address.txt', token.address)
        //file written successfully
    } catch (err) {
        console.error(err)
    }

    await token.deployed();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
});