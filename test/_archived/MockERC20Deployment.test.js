const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("MockERC20 Deployment", function () {
    const ADMIN_ADDRESS = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";

    async function deployFixture() {
        // Impersonate the admin account
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [ADMIN_ADDRESS],
        });

        const adminSigner = await ethers.getSigner(ADMIN_ADDRESS);

        // Fund the impersonated admin account with ETH
        const [funder] = await ethers.getSigners();
        await funder.sendTransaction({
            to: ADMIN_ADDRESS,
            value: ethers.parseEther("10.0"),
        });

        // Deploy MockERC20 with 18 decimals
        const MockERC20 = await ethers.getContractFactory("MockERC20", adminSigner);
        const mockToken = await MockERC20.deploy("Mock Token", "MTK", 18);
        await mockToken.waitForDeployment();

        // Stop impersonating
        await network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [ADMIN_ADDRESS],
        });

        return { mockToken };
    }

    it("Should deploy MockERC20 correctly with 18 decimals", async function () {
        const { mockToken } = await deployFixture();
        expect(await mockToken.name()).to.equal("Mock Token");
        expect(await mockToken.symbol()).to.equal("MTK");
        expect(await mockToken.decimals()).to.equal(18);
    });
});
