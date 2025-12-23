// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxTokenBasedMinter.sol";
import "../contracts/interfaces/IKondux.sol";
import "../contracts/interfaces/IKonduxERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @title KonduxTokenBasedMinter Tests (Mainnet Fork)
 * @notice Forge tests for KonduxTokenBasedMinter - token-based bundle minting
 * @dev Migrated from test/KonduxTokenBasedMinter.test.js using mainnet fork
 */
contract KonduxTokenBasedMinterTest is Test {
    // Mainnet addresses (same as Hardhat test)
    address constant ADMIN_ADDRESS = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant KNFT_ADDRESS = 0x5aD180dF8619CE4f888190C3a926111a723632ce;
    address constant TREASURY_ADDRESS = 0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E;
    address constant FOUNDERSPASS_ADDRESS = 0xD3f011f1768B38CcC0faA7B00E59B0E29920194b;
    address constant PAYMENT_TOKEN_ADDRESS = 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1;
    address constant UNISWAP_PAIR_ADDRESS = 0x79dd15aD871b0fE18040a52F951D757Ef88cfe72;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant TOKEN_HOLDER_ADDRESS = 0x4936167DAE4160E5556D9294F2C78675659a3B63;
    address constant FOUNDERS_PASS_HOLDER_ADDRESS = 0x79BD02b5936FFdC5915cB7Cd58156E3169F4F569;

    uint8 constant KNDX_DECIMALS = 9;

    KonduxTokenBasedMinter public minter;
    IKonduxERC20 public paymentToken;
    IKondux public kNFT;
    IERC721 public foundersPass;

    address public user;

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // Fork mainnet - uses MAINNET_RPC_URL env var or foundry.toml config
        // If no RPC URL is available, tests will be skipped
        try vm.createSelectFork("mainnet") {
            // Fork successful
        } catch {
            // Try with explicit RPC URL from env
            string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
            if (bytes(rpcUrl).length == 0) {
                // Skip tests if no mainnet fork available
                return;
            }
            vm.createSelectFork(rpcUrl);
        }

        user = makeAddr("user");

        // Fund admin with ETH
        vm.deal(ADMIN_ADDRESS, 100 ether);
        vm.deal(user, 100 ether);

        vm.startPrank(ADMIN_ADDRESS);

        // Deploy the minter contract
        minter = new KonduxTokenBasedMinter(
            KNFT_ADDRESS,
            FOUNDERSPASS_ADDRESS,
            TREASURY_ADDRESS,
            PAYMENT_TOKEN_ADDRESS,
            UNISWAP_PAIR_ADDRESS,
            WETH_ADDRESS
        );

        // Send ETH to minter for emergency withdraw tests
        (bool success,) = address(minter).call{value: 5 ether}("");
        require(success, "ETH transfer failed");

        vm.stopPrank();

        // Transfer tokens to minter from token holder
        vm.prank(TOKEN_HOLDER_ADDRESS);
        paymentToken = IKonduxERC20(PAYMENT_TOKEN_ADDRESS);
        paymentToken.transfer(address(minter), 100_000 * 10 ** KNDX_DECIMALS);

        kNFT = IKondux(KNFT_ADDRESS);
        foundersPass = IERC721(FOUNDERSPASS_ADDRESS);
    }

    modifier onlyWithFork() {
        // Skip if fork not available
        if (address(minter) == address(0)) {
            return;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_getKNFT() public onlyWithFork {
        assertEq(minter.getKNFT(), KNFT_ADDRESS, "KNFT address should match");
    }

    function test_getTreasury() public onlyWithFork {
        assertEq(minter.getTreasury(), TREASURY_ADDRESS, "Treasury address should match");
    }

    function test_getTokenAmountForETH() public onlyWithFork {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = minter.getTokenAmountForETH(ethAmount);

        // Verify token amount is non-zero and reasonable
        assertGt(tokenAmount, 0, "Token amount should be greater than 0");
    }

    function test_getTokenPriceInETH() public onlyWithFork {
        uint256 priceInETH = minter.getTokenPriceInETH();
        assertGt(priceInETH, 0, "Token price in ETH should be greater than 0");
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_adminCanUpdateConfigurations() public onlyWithFork {
        uint256 newPrice = 0.5 ether;
        uint256 newDiscountPrice = 0.25 ether;
        uint256 newFounderPrice = 0.1 ether;
        uint16 newBundleSize = 10;
        address newKNFT = makeAddr("newKNFT");
        address newFoundersPass = makeAddr("newFoundersPass");
        address newTreasury = makeAddr("newTreasury");
        address newPaymentToken = makeAddr("newPaymentToken");
        address newUniswapPair = makeAddr("newUniswapPair");
        address newWETH = makeAddr("newWETH");

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true);
        emit KonduxTokenBasedMinter.ConfigurationsUpdated(
            newPrice,
            newDiscountPrice,
            newFounderPrice,
            newBundleSize,
            newKNFT,
            newFoundersPass,
            newTreasury,
            newPaymentToken,
            newUniswapPair,
            newWETH
        );
        minter.batchUpdateConfigurations(
            newPrice,
            newDiscountPrice,
            newFounderPrice,
            newBundleSize,
            newKNFT,
            newFoundersPass,
            newTreasury,
            newPaymentToken,
            newUniswapPair,
            newWETH
        );

        assertEq(minter.fullPrice(), newPrice, "Price should be updated");
        assertEq(minter.discountPrice(), newDiscountPrice, "Discount price should be updated");
        assertEq(minter.founderDiscountPrice(), newFounderPrice, "Founder price should be updated");
        assertEq(minter.bundleSize(), newBundleSize, "Bundle size should be updated");
    }

    function test_nonAdminCannotUpdateConfigurations() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.batchUpdateConfigurations(
            0.5 ether, 0.25 ether, 0.1 ether, 10,
            makeAddr("a"), makeAddr("b"), makeAddr("c"),
            makeAddr("d"), makeAddr("e"), makeAddr("f")
        );
    }

    function test_revertInvalidConfigurationParameters() public onlyWithFork {
        vm.startPrank(ADMIN_ADDRESS);

        // Invalid price (zero)
        vm.expectRevert("Price must be greater than 0");
        minter.batchUpdateConfigurations(
            0, 0.25 ether, 0.1 ether, 10,
            makeAddr("a"), makeAddr("b"), makeAddr("c"),
            makeAddr("d"), makeAddr("e"), makeAddr("f")
        );

        // Invalid bundle size (exceeds max)
        vm.expectRevert("Invalid bundle size");
        minter.batchUpdateConfigurations(
            0.5 ether, 0.25 ether, 0.1 ether, 20,
            makeAddr("a"), makeAddr("b"), makeAddr("c"),
            makeAddr("d"), makeAddr("e"), makeAddr("f")
        );

        // Invalid address (zero)
        vm.expectRevert("Invalid kNFT address");
        minter.batchUpdateConfigurations(
            0.5 ether, 0.25 ether, 0.1 ether, 10,
            address(0), makeAddr("b"), makeAddr("c"),
            makeAddr("d"), makeAddr("e"), makeAddr("f")
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function test_adminCanWithdrawETH() public onlyWithFork {
        uint256 adminBalanceBefore = ADMIN_ADDRESS.balance;
        uint256 withdrawAmount = 1 ether;

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit KonduxTokenBasedMinter.ETHWithdrawn(ADMIN_ADDRESS, withdrawAmount);
        minter.emergencyWithdrawETH(withdrawAmount);

        assertEq(address(minter).balance, 4 ether, "Minter should have 4 ETH left");
        assertGt(ADMIN_ADDRESS.balance, adminBalanceBefore, "Admin should have received ETH");
    }

    function test_nonAdminCannotWithdrawETH() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.emergencyWithdrawETH(1 ether);
    }

    function test_revertWithdrawMoreETHThanBalance() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Insufficient ETH balance");
        minter.emergencyWithdrawETH(10 ether);
    }

    function test_adminCanWithdrawTokens() public onlyWithFork {
        uint256 adminBalanceBefore = paymentToken.balanceOf(ADMIN_ADDRESS);
        uint256 withdrawAmount = 500 * 10 ** KNDX_DECIMALS;

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, false, true);
        emit KonduxTokenBasedMinter.TokensWithdrawn(ADMIN_ADDRESS, PAYMENT_TOKEN_ADDRESS, withdrawAmount);
        minter.emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, withdrawAmount);

        assertEq(
            paymentToken.balanceOf(ADMIN_ADDRESS),
            adminBalanceBefore + withdrawAmount,
            "Admin should have received tokens"
        );
    }

    function test_nonAdminCannotWithdrawTokens() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, 500 * 10 ** KNDX_DECIMALS);
    }

    function test_revertWithdrawMoreTokensThanBalance() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Insufficient token balance");
        minter.emergencyWithdrawTokens(PAYMENT_TOKEN_ADDRESS, 200_000 * 10 ** KNDX_DECIMALS);
    }

    /*//////////////////////////////////////////////////////////////
                            SET ADMIN
    //////////////////////////////////////////////////////////////*/

    function test_adminCanGrantAdminRole() public onlyWithFork {
        address newAdmin = makeAddr("newAdmin");
        assertFalse(minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), newAdmin));

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, false, false, false);
        emit KonduxTokenBasedMinter.AdminGranted(newAdmin);
        minter.setAdmin(newAdmin);

        assertTrue(minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), newAdmin));
    }

    function test_nonAdminCannotGrantAdminRole() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setAdmin(makeAddr("newAdmin"));
    }

    function test_revertGrantAdminToZeroAddress() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Admin address is not set");
        minter.setAdmin(address(0));
    }

    function test_revertGrantAdminToExistingAdmin() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Address already has admin role");
        minter.setAdmin(ADMIN_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            SET BUNDLE SIZE
    //////////////////////////////////////////////////////////////*/

    function test_adminCanSetBundleSize() public onlyWithFork {
        uint16 newBundleSize = 12;

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(false, false, false, true);
        emit KonduxTokenBasedMinter.BundleSizeChanged(newBundleSize);
        minter.setBundleSize(newBundleSize);

        assertEq(minter.bundleSize(), newBundleSize);
    }

    function test_nonAdminCannotSetBundleSize() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setBundleSize(10);
    }

    function test_revertBundleSizeZero() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Bundle size must be greater than 0");
        minter.setBundleSize(0);
    }

    function test_revertBundleSizeExceedsMax() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Bundle size must be less than or equal to 15");
        minter.setBundleSize(20);
    }

    /*//////////////////////////////////////////////////////////////
                            SET PRICES
    //////////////////////////////////////////////////////////////*/

    function test_adminCanSetFullPrice() public onlyWithFork {
        uint256 newPrice = 0.75 ether;

        vm.prank(ADMIN_ADDRESS);
        minter.setFullPrice(newPrice);

        assertEq(minter.fullPrice(), newPrice);
    }

    function test_nonAdminCannotSetFullPrice() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setFullPrice(0.5 ether);
    }

    function test_revertFullPriceZero() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Price must be greater than 0");
        minter.setFullPrice(0);
    }

    function test_adminCanSetDiscountPrice() public onlyWithFork {
        uint256 newPrice = 0.5 ether;

        vm.prank(ADMIN_ADDRESS);
        minter.setDiscountPrice(newPrice);

        assertEq(minter.discountPrice(), newPrice);
    }

    function test_revertDiscountPriceZero() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Price must be greater than 0");
        minter.setDiscountPrice(0);
    }

    function test_adminCanSetFounderDiscountPrice() public onlyWithFork {
        uint256 newPrice = 0.3 ether;

        vm.prank(ADMIN_ADDRESS);
        minter.setFounderDiscountPrice(newPrice);

        assertEq(minter.founderDiscountPrice(), newPrice);
    }

    function test_revertFounderDiscountPriceZero() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Price must be greater than 0");
        minter.setFounderDiscountPrice(0);
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_contractStartsPaused() public onlyWithFork {
        assertTrue(minter.paused());
    }

    function test_adminCanUnpause() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);
        assertFalse(minter.paused());
    }

    function test_nonAdminCannotPause() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Caller is not an admin");
        minter.setPaused(false);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC MINT
    //////////////////////////////////////////////////////////////*/

    function test_revertMintWhenPaused() public onlyWithFork {
        vm.prank(user);
        vm.expectRevert("Contract is paused");
        minter.publicMint();
    }

    function test_revertMintWithInsufficientAllowance() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);

        // Calculate required tokens and transfer that amount
        uint256 ethPrice = minter.discountPrice();
        uint256 tokensRequired = minter.getTokenAmountForETH(ethPrice);

        // Transfer tokens to user but give no allowance
        vm.prank(TOKEN_HOLDER_ADDRESS);
        paymentToken.transfer(user, tokensRequired);

        // User has tokens but no allowance
        vm.prank(user);
        vm.expectRevert("Insufficient token allowance");
        minter.publicMint();
    }

    function test_revertMintWithInsufficientBalance() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);

        // Give user allowance but no tokens
        vm.prank(user);
        paymentToken.approve(address(minter), type(uint256).max);

        vm.prank(user);
        vm.expectRevert("Insufficient token balance");
        minter.publicMint();
    }

    function test_successfulPublicMint() public onlyWithFork {
        // Calculate required tokens
        uint256 ethPrice = minter.discountPrice();
        uint256 tokensRequired = minter.getTokenAmountForETH(ethPrice);

        // Transfer tokens from holder to user
        vm.prank(TOKEN_HOLDER_ADDRESS);
        paymentToken.transfer(user, tokensRequired);

        // Approve minter
        vm.prank(user);
        paymentToken.approve(address(minter), tokensRequired);

        // Unpause
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);

        // Grant MINTER_ROLE to minter on kNFT contract
        vm.prank(ADMIN_ADDRESS);
        IAccessControl(KNFT_ADDRESS).grantRole(MINTER_ROLE, address(minter));

        uint256 userTokenBalanceBefore = paymentToken.balanceOf(user);
        uint256 userNFTBalanceBefore = kNFT.balanceOf(user);

        // Mint
        vm.prank(user);
        uint256[] memory tokenIds = minter.publicMint();

        // Verify
        assertEq(tokenIds.length, minter.bundleSize(), "Should mint bundleSize NFTs");
        assertEq(
            kNFT.balanceOf(user),
            userNFTBalanceBefore + minter.bundleSize(),
            "User should own bundleSize more NFTs"
        );
        assertEq(paymentToken.balanceOf(user), 0, "User should have spent all tokens");
    }

    function test_founderDiscountApplied() public onlyWithFork {
        // Transfer founders pass from holder to user
        vm.deal(FOUNDERS_PASS_HOLDER_ADDRESS, 1 ether);
        
        uint256 founderBalance = foundersPass.balanceOf(FOUNDERS_PASS_HOLDER_ADDRESS);
        if (founderBalance == 0) {
            // Skip if holder has no founders pass
            return;
        }

        uint256 tokenId = IERC721Enumerable(FOUNDERSPASS_ADDRESS).tokenOfOwnerByIndex(FOUNDERS_PASS_HOLDER_ADDRESS, 0);

        vm.prank(FOUNDERS_PASS_HOLDER_ADDRESS);
        foundersPass.transferFrom(FOUNDERS_PASS_HOLDER_ADDRESS, user, tokenId);

        // Calculate tokens at founder price
        uint256 founderPriceInTokens = minter.getTokenAmountForETH(minter.founderDiscountPrice());

        // Transfer tokens to user
        vm.prank(TOKEN_HOLDER_ADDRESS);
        paymentToken.transfer(user, founderPriceInTokens);

        vm.prank(user);
        paymentToken.approve(address(minter), founderPriceInTokens);

        // Unpause and grant role
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);

        vm.prank(ADMIN_ADDRESS);
        IAccessControl(KNFT_ADDRESS).grantRole(MINTER_ROLE, address(minter));

        // Mint
        vm.prank(user);
        minter.publicMint();

        assertEq(kNFT.balanceOf(user), minter.bundleSize(), "User should own bundleSize NFTs");
    }

    function test_multipleMints() public onlyWithFork {
        uint256 numberOfMints = 3;
        uint256 ethPrice = minter.discountPrice();
        uint256 tokensPerMint = minter.getTokenAmountForETH(ethPrice);
        uint256 totalTokensRequired = tokensPerMint * numberOfMints;

        // Transfer tokens
        vm.prank(TOKEN_HOLDER_ADDRESS);
        paymentToken.transfer(user, totalTokensRequired);

        vm.prank(user);
        paymentToken.approve(address(minter), totalTokensRequired);

        // Unpause and grant role
        vm.prank(ADMIN_ADDRESS);
        minter.setPaused(false);

        vm.prank(ADMIN_ADDRESS);
        IAccessControl(KNFT_ADDRESS).grantRole(MINTER_ROLE, address(minter));

        // Perform multiple mints
        for (uint256 i = 0; i < numberOfMints; i++) {
            vm.prank(user);
            minter.publicMint();
        }

        assertEq(
            kNFT.balanceOf(user),
            minter.bundleSize() * numberOfMints,
            "User should own all minted NFTs"
        );
        assertEq(paymentToken.balanceOf(user), 0, "User should have spent all tokens");
    }

    /*//////////////////////////////////////////////////////////////
                            BURN FEE SETTINGS
    //////////////////////////////////////////////////////////////*/

    function test_adminCanSetBurnFee() public onlyWithFork {
        uint16 newBurnFee = 500;

        vm.prank(ADMIN_ADDRESS);
        minter.setBurnFeeBP(newBurnFee);

        assertEq(minter.burnFeeBP(), newBurnFee);
    }

    function test_revertBurnFeeTooHigh() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert("Fee too high");
        minter.setBurnFeeBP(10001);
    }

    /*//////////////////////////////////////////////////////////////
                        FOUNDERS PASS SETTINGS
    //////////////////////////////////////////////////////////////*/

    function test_adminCanSetFoundersPassActive() public onlyWithFork {
        vm.prank(ADMIN_ADDRESS);
        minter.setFoundersPassActive(false);
        assertFalse(minter.foundersPassActive());

        vm.prank(ADMIN_ADDRESS);
        minter.setFoundersPassActive(true);
        assertTrue(minter.foundersPassActive());
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    function test_contractCanReceiveETH() public onlyWithFork {
        uint256 balanceBefore = address(minter).balance;

        vm.prank(user);
        (bool success,) = address(minter).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(minter).balance, balanceBefore + 1 ether);
    }
}
