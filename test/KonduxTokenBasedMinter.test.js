const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("KonduxTokenBasedMinter - Comprehensive Tests", function () {
    // Deployed contract addresses as provided
    const ADMIN_ADDRESS = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";
    const KNFT_ADDRESS = "0x5aD180dF8619CE4f888190C3a926111a723632ce";
    const TREASURY_ADDRESS = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E";
    const FOUNDERSPASS_ADDRESS = "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b";
    const PAYMENT_TOKEN_ADDRESS = "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1";
    const UNISWAP_PAIR_ADDRESS = "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72";
    const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const UNISWAP_V2_ROUTER_ADDRESS = "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD";

    const KNDX_DECIMALS = 9;
    
    // Address of an account holding a significant amount of PAYMENT_TOKEN_ADDRESS
    const TOKEN_HOLDER_ADDRESS = "0x4936167DAE4160E5556D9294F2C78675659a3B63"; 
    
    // Fixture to set up the testing environment
    async function deployFixture() {
        // Impersonate the admin account
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [ADMIN_ADDRESS],
        });

        // Get the signer for the impersonated admin account
        const adminSigner = await ethers.getSigner(ADMIN_ADDRESS);

        // Fund the impersonated account with ETH if necessary
        const [funder] = await ethers.getSigners();
        // Transfer ETH from funder to adminSigner
        await funder.sendTransaction({
            to: ADMIN_ADDRESS,
            value: ethers.parseEther("10.0"),
        });

        // Deploy the KonduxTokenBasedMinter contract with the dependencies
        const KonduxTokenBasedMinter = await ethers.getContractFactory("KonduxTokenBasedMinter", adminSigner);
        const konduxTokenBasedMinter = await KonduxTokenBasedMinter.deploy(
            KNFT_ADDRESS,
            FOUNDERSPASS_ADDRESS,
            TREASURY_ADDRESS,
            PAYMENT_TOKEN_ADDRESS,
            UNISWAP_PAIR_ADDRESS,
            WETH_ADDRESS,
            {
                // Set higher gas fee parameters to accommodate the forked network's base fee
                maxFeePerGas: ethers.parseUnits("100", "gwei"),         // 100 gwei
                maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),    // 2 gwei
            }
        );

        await konduxTokenBasedMinter.waitForDeployment();

        const konduxTokenBasedMinterAddress = await konduxTokenBasedMinter.getAddress();
        console.log("KonduxTokenBasedMinter deployed to:", konduxTokenBasedMinterAddress);

        // Transfer ETH to the minter contract for testing emergencyWithdrawETH
        await adminSigner.sendTransaction({
            to: konduxTokenBasedMinterAddress,
            value: ethers.parseEther("5.0"), // 5 ETH
        });

        // Impersonate the token holder to transfer PAYMENT_TOKEN_ADDRESS tokens to the minter contract
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [TOKEN_HOLDER_ADDRESS],
        });
        const tokenHolderSigner = await ethers.getSigner(TOKEN_HOLDER_ADDRESS);

        // // Connect to the payment token contract
        const paymentToken = await ethers.getContractAt("KNDX", PAYMENT_TOKEN_ADDRESS, tokenHolderSigner);

        // // Determine the amount to transfer (e.g., 1000 tokens with 9 decimals)
        const transferAmount = ethers.parseUnits("1000", KNDX_DECIMALS); // Adjust decimals if necessary

        // // Transfer tokens to the minter contract
        await paymentToken.transfer(konduxTokenBasedMinterAddress, transferAmount);

        // // Stop impersonating the token holder and admin accounts to save resources
        await network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [TOKEN_HOLDER_ADDRESS],
        });
        // await network.provider.request({
        //     method: "hardhat_stopImpersonatingAccount",
        //     params: [ADMIN_ADDRESS],
        // });

        // // Impersonate the admin account
        // await network.provider.request({
        //     method: "hardhat_impersonateAccount",
        //     params: [ADMIN_ADDRESS],
        // });

        return {
            adminSigner,
            konduxTokenBasedMinter,
            tokenHolderSigner, // Not strictly necessary after transfer
        };
    }

    describe("Getter Functions", function () {
        it("getKNFT() should return the correct KNFT address", async function () {
            const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
            const knftAddress = await konduxTokenBasedMinter.getKNFT();
            expect(knftAddress).to.equal(KNFT_ADDRESS);
        });

        it("getTreasury() should return the correct Treasury address", async function () {
            const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
            const treasuryAddress = await konduxTokenBasedMinter.getTreasury();
            expect(treasuryAddress).to.equal(TREASURY_ADDRESS);
        });

        it("getTokenAmountForETH() should return the correct token amount for a given ETH amount", async function () {
            const { konduxTokenBasedMinter } = await loadFixture(deployFixture);

            // Example ETH amount to test (e.g., 1 ETH)
            const ethAmount = ethers.parseEther("1.0"); // 1 ETH in wei

            // Fetch reserves from Uniswap pair
            const uniswapPair = await ethers.getContractAt("IUniswapV2Pair", UNISWAP_PAIR_ADDRESS);
            const reserves = await uniswapPair.getReserves();
            const token0 = await uniswapPair.token0();
            let reserveETH, reserveToken;

            if (token0.toLowerCase() === WETH_ADDRESS.toLowerCase()) {
                reserveETH = reserves.reserve0;
                reserveToken = reserves.reserve1;
            } else {
                reserveETH = reserves.reserve1;
                reserveToken = reserves.reserve0;
            }

            // Fetch token decimals from paymentToken
            const paymentToken = await ethers.getContractAt("IKonduxERC20", PAYMENT_TOKEN_ADDRESS);
            const tokenDecimals = await paymentToken.decimals();

            // Calculate expected token amount off-chain
            let expectedTokenAmount;
            if (tokenDecimals < 18) {
                expectedTokenAmount = ethAmount * reserveToken * (10n ** BigInt(tokenDecimals)) / (reserveETH * (10n ** 18n));
            } else if (tokenDecimals > 18) {
                const decimalDifference = BigInt(tokenDecimals) - 18n;                
                expectedTokenAmount = ethAmount * reserveToken * (10n ** decimalDifference) / reserveETH;
            } else {
                expectedTokenAmount = ethAmount * reserveToken / reserveETH;
            }

            // Convert expectedTokenAmount from BigInt to string for comparison
            const expectedTokenAmountStr = expectedTokenAmount.toString();

            // Fetch token amount from the contract's getter
            const tokenAmountFromContract = await konduxTokenBasedMinter.getTokenAmountForETH(ethAmount);

            // Compare the two amounts
            expect(tokenAmountFromContract.toString()).to.equal(expectedTokenAmountStr);
        });

        it("getTokenPriceInETH() should return the correct token price in ETH", async function () {
            const { konduxTokenBasedMinter } = await loadFixture(deployFixture);

            // Fetch reserves from Uniswap pair
            const uniswapPair = await ethers.getContractAt("IUniswapV2Pair", UNISWAP_PAIR_ADDRESS);
            const reserves = await uniswapPair.getReserves();
            const token0 = await uniswapPair.token0();
            let reserveETH, reserveToken;

            if (token0.toLowerCase() === WETH_ADDRESS.toLowerCase()) {
                reserveETH = reserves.reserve0;
                reserveToken = reserves.reserve1;
            } else {
                reserveETH = reserves.reserve1;
                reserveToken = reserves.reserve0;
            }

            // Fetch token decimals from paymentToken
            const paymentToken = await ethers.getContractAt("IKonduxERC20", PAYMENT_TOKEN_ADDRESS);
            const tokenDecimals = await paymentToken.decimals();

            // Calculate expected price off-chain
            let expectedPriceInETH;
            if (tokenDecimals < 18) {                
                expectedPriceInETH = reserveETH * (10n ** 18n) / (reserveToken * (10n ** BigInt(tokenDecimals)));
            } else if (tokenDecimals > 18) {
                const decimalDifference = BigInt(tokenDecimals) - 18n;                
                expectedPriceInETH = reserveETH * (10n ** 18n) / (reserveToken * (10n ** decimalDifference));
            } else {                
                expectedPriceInETH = reserveETH * (10n ** 18n) / reserveToken;
            }

            // Fetch token price from the contract's getter
            const priceInETHFromContract = await konduxTokenBasedMinter.getTokenPriceInETH();

            // Compare the two prices
            expect(priceInETHFromContract.toString()).to.equal(expectedPriceInETH.toString());
        });
    });

    describe("Admin Functions", function () {
        describe("batchUpdateConfigurations", function () {
            it("should allow admin to update configurations with valid parameters", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Define new configuration parameters
                const newPrice = ethers.parseEther("0.5"); // 0.5 ETH
                const newBundleSize = 10;
                const newKNFT = "0x0000000000000000000000000000000000000001"; // Example address
                const newFoundersPass = "0x0000000000000000000000000000000000000002"; // Example address
                const newTreasury = "0x0000000000000000000000000000000000000003"; // Example address
                const newPaymentToken = "0x0000000000000000000000000000000000000004"; // Example address
                const newUniswapPair = "0x0000000000000000000000000000000000000005"; // Example address
                const newWETH = "0x0000000000000000000000000000000000000006"; // Example address

                // Call batchUpdateConfigurations
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).batchUpdateConfigurations(
                        newPrice,
                        newBundleSize,
                        newKNFT,
                        newFoundersPass,
                        newTreasury,
                        newPaymentToken,
                        newUniswapPair,
                        newWETH
                    )
                )
                .to.emit(konduxTokenBasedMinter, "ConfigurationsUpdated")
                .withArgs(
                    newPrice,
                    newBundleSize,
                    newKNFT,
                    newFoundersPass,
                    newTreasury,
                    newPaymentToken,
                    newUniswapPair,
                    newWETH
                );

                // Verify updates
                expect(await konduxTokenBasedMinter.price()).to.equal(newPrice);
                expect(await konduxTokenBasedMinter.bundleSize()).to.equal(newBundleSize);
                expect(await konduxTokenBasedMinter.getKNFT()).to.equal(newKNFT);
                expect(await konduxTokenBasedMinter.getTreasury()).to.equal(newTreasury);
                expect(await konduxTokenBasedMinter.foundersPass()).to.equal(newFoundersPass);
                expect(await konduxTokenBasedMinter.paymentToken()).to.equal(newPaymentToken);
                expect(await konduxTokenBasedMinter.uniswapPair()).to.equal(newUniswapPair);
                expect(await konduxTokenBasedMinter.WETH()).to.equal(newWETH);
            });

            it("should revert when non-admin tries to update configurations", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin] = await ethers.getSigners();

                // Attempt to call batchUpdateConfigurations as non-admin
                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).batchUpdateConfigurations(
                        ethers.parseEther("0.5"),
                        10,
                        "0x0000000000000000000000000000000000000001",
                        "0x0000000000000000000000000000000000000002",
                        "0x0000000000000000000000000000000000000003",
                        "0x0000000000000000000000000000000000000004",
                        "0x0000000000000000000000000000000000000005",
                        "0x0000000000000000000000000000000000000006"
                    )
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when updating with invalid parameters", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Define invalid configuration parameters
                const invalidPrice = 0; // Invalid price
                const invalidBundleSize = 20; // Exceeds maximum
                const invalidAddress = ethers.ZeroAddress // Zero address

                // Attempt to call batchUpdateConfigurations with invalid price
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).batchUpdateConfigurations(
                        invalidPrice,
                        10,
                        "0x0000000000000000000000000000000000000001",
                        "0x0000000000000000000000000000000000000002",
                        "0x0000000000000000000000000000000000000003",
                        "0x0000000000000000000000000000000000000004",
                        "0x0000000000000000000000000000000000000005",
                        "0x0000000000000000000000000000000000000006"
                    )
                ).to.be.revertedWith("Price must be greater than 0");

                // Attempt to call batchUpdateConfigurations with invalid bundle size
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).batchUpdateConfigurations(
                        ethers.parseEther("0.5"),
                        invalidBundleSize,
                        "0x0000000000000000000000000000000000000001",
                        "0x0000000000000000000000000000000000000002",
                        "0x0000000000000000000000000000000000000003",
                        "0x0000000000000000000000000000000000000004",
                        "0x0000000000000000000000000000000000000005",
                        "0x0000000000000000000000000000000000000006"
                    )
                ).to.be.revertedWith("Invalid bundle size");

                // Attempt to call batchUpdateConfigurations with zero address
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).batchUpdateConfigurations(
                        ethers.parseEther("0.5"),
                        10,
                        invalidAddress,
                        "0x0000000000000000000000000000000000000002",
                        "0x0000000000000000000000000000000000000003",
                        "0x0000000000000000000000000000000000000004",
                        "0x0000000000000000000000000000000000000005",
                        "0x0000000000000000000000000000000000000006"
                    )
                ).to.be.revertedWith("Invalid kNFT address");
            });
        });

        describe("emergencyWithdrawETH", function () {
            it("should allow admin to withdraw ETH", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const konduxTokenBasedMinterAddress = await konduxTokenBasedMinter.getAddress();
                const adminSignerAddress = await adminSigner.getAddress();

                // Check initial ETH balance of admin
                const initialAdminBalance = await ethers.provider.getBalance(adminSignerAddress);
                // Check initial ETH balance of minter
                const initialMinterBalance = await ethers.provider.getBalance(konduxTokenBasedMinterAddress);

                // Define withdrawal amount (e.g., 1 ETH)
                const withdrawAmount = ethers.parseEther("1.0");

                // Perform withdrawal
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).emergencyWithdrawETH(withdrawAmount)
                )
                .to.emit(konduxTokenBasedMinter, "ETHWithdrawn")
                .withArgs(adminSignerAddress, withdrawAmount);

                // Check final balances
                const finalAdminBalance = await ethers.provider.getBalance(adminSigner);
                const finalMinterBalance = await ethers.provider.getBalance(konduxTokenBasedMinterAddress);

                expect(finalMinterBalance).to.equal(initialMinterBalance - withdrawAmount);
                expect(finalAdminBalance).to.be.above(initialAdminBalance);
            });

            it("should revert when non-admin tries to withdraw ETH", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin] = await ethers.getSigners();

                const withdrawAmount = ethers.parseEther("1.0");

                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).emergencyWithdrawETH(withdrawAmount)
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when trying to withdraw more ETH than the contract balance", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Define a withdrawal amount greater than the minter's balance (e.g., 10 ETH)
                const withdrawAmount = ethers.parseEther("10.0"); // Minter has only 5 ETH

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).emergencyWithdrawETH(withdrawAmount)
                ).to.be.revertedWith("Insufficient ETH balance");
            });
        });

        describe("emergencyWithdrawTokens", function () {
            it("should allow admin to withdraw ERC20 tokens", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Connect to the payment token contract
                const paymentToken = await ethers.getContractAt("IKonduxERC20", PAYMENT_TOKEN_ADDRESS);

                const konduxTokenBasedMinterAddress = await konduxTokenBasedMinter.getAddress();
                const adminSignerAddress = await adminSigner.getAddress();

                // Check initial token balance of admin
                const initialAdminTokenBalance = await paymentToken.balanceOf(adminSignerAddress);
                // Check initial token balance of minter
                const initialMinterTokenBalance = await paymentToken.balanceOf(konduxTokenBasedMinterAddress);

                // Define withdrawal amount (e.g., 500 tokens)
                const withdrawAmount = ethers.parseUnits("500", KNDX_DECIMALS); // Adjust decimals if necessary

                // Perform withdrawal
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, withdrawAmount)
                )
                .to.emit(konduxTokenBasedMinter, "TokensWithdrawn")
                .withArgs(adminSignerAddress, PAYMENT_TOKEN_ADDRESS, withdrawAmount);

                // Check final balances
                const finalAdminTokenBalance = await paymentToken.balanceOf(adminSignerAddress);
                const finalMinterTokenBalance = await paymentToken.balanceOf(konduxTokenBasedMinterAddress);

                expect(finalMinterTokenBalance).to.equal(initialMinterTokenBalance - withdrawAmount);
                expect(finalAdminTokenBalance).to.equal(initialAdminTokenBalance + withdrawAmount);
            });

            it("should revert when non-admin tries to withdraw ERC20 tokens", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin] = await ethers.getSigners();

                const withdrawAmount = ethers.parseUnits("500", KNDX_DECIMALS); // Adjust decimals if necessary

                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, withdrawAmount)
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when trying to withdraw more tokens than the contract balance", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Connect to the payment token contract
                const paymentToken = await ethers.getContractAt("IKonduxERC20", PAYMENT_TOKEN_ADDRESS);

                // Define a withdrawal amount greater than the minter's balance (e.g., 2000 tokens)
                const withdrawAmount = ethers.parseUnits("2000", KNDX_DECIMALS); // Minter has only 1000 tokens

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, withdrawAmount)
                ).to.be.revertedWith("Insufficient token balance");
            });
        });

        describe("setAdmin", function () {
            it("should allow admin to grant admin role to a new address", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, newAdmin] = await ethers.getSigners();

                // Ensure newAdmin does not have admin role initially
                expect(await konduxTokenBasedMinter.hasRole(await konduxTokenBasedMinter.DEFAULT_ADMIN_ROLE(), newAdmin.address)).to.be.false;

                // Grant admin role
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setAdmin(newAdmin.address)
                )
                .to.emit(konduxTokenBasedMinter, "AdminGranted")
                .withArgs(newAdmin.address);

                // Verify newAdmin has admin role
                expect(await konduxTokenBasedMinter.hasRole(await konduxTokenBasedMinter.DEFAULT_ADMIN_ROLE(), newAdmin.address)).to.be.true;
            });

            it("should revert when non-admin tries to grant admin role", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin, newAdmin] = await ethers.getSigners();

                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).setAdmin(newAdmin.address)
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when trying to grant admin role to zero address", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setAdmin(ethers.ZeroAddress)
                ).to.be.revertedWith("Admin address is not set");
            });

            it("should revert when trying to grant admin role to an already admin address", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                // Attempt to grant admin role to the existing admin
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setAdmin(ADMIN_ADDRESS)
                ).to.be.revertedWith("Address already has admin role");
            });
        });

        describe("setBundleSize", function () {
            it("should allow admin to set a valid bundle size", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const newBundleSize = 12;

                // Call setBundleSize
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setBundleSize(newBundleSize)
                )
                .to.emit(konduxTokenBasedMinter, "BundleSizeChanged")
                .withArgs(newBundleSize);

                // Verify update
                expect(await konduxTokenBasedMinter.bundleSize()).to.equal(newBundleSize);
            });

            it("should revert when non-admin tries to set bundle size", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin] = await ethers.getSigners();

                const newBundleSize = 10;

                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).setBundleSize(newBundleSize)
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when setting bundle size to zero", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const invalidBundleSize = 0;

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setBundleSize(invalidBundleSize)
                ).to.be.revertedWith("Bundle size must be greater than 0");
            });

            it("should revert when setting bundle size above maximum limit", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const invalidBundleSize = 20; // Exceeds maximum of 15

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setBundleSize(invalidBundleSize)
                ).to.be.revertedWith("Bundle size must be less than or equal to 15");
            });
        });

        describe("setPrice", function () {
            it("should allow admin to set a valid price", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const newPrice = ethers.parseEther("0.75"); // 0.75 ETH

                // Call setPrice
                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setPrice(newPrice)
                )
                .to.emit(konduxTokenBasedMinter, "PriceChanged")
                .withArgs(newPrice);

                // Verify update
                expect(await konduxTokenBasedMinter.price()).to.equal(newPrice);
            });

            it("should revert when non-admin tries to set price", async function () {
                const { konduxTokenBasedMinter } = await loadFixture(deployFixture);
                const [_, nonAdmin] = await ethers.getSigners();

                const newPrice = ethers.parseEther("0.5"); // 0.5 ETH

                await expect(
                    konduxTokenBasedMinter.connect(nonAdmin).setPrice(newPrice)
                ).to.be.revertedWith("Caller is not an admin");
            });

            it("should revert when setting price to zero", async function () {
                const { adminSigner, konduxTokenBasedMinter } = await loadFixture(deployFixture);

                const invalidPrice = 0;

                await expect(
                    konduxTokenBasedMinter.connect(adminSigner).setPrice(invalidPrice)
                ).to.be.revertedWith("Price must be greater than 0");
            });
        });
    });
});
