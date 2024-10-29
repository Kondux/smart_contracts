// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import Interfaces
import "./interfaces/IKondux.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IKonduxERC20.sol";

// Import OpenZeppelin Contracts
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KonduxTokenBasedMinter is AccessControl, ReentrancyGuard {
    // State Variables
    bool public paused; // Controls whether minting is currently allowed.
    uint16 public bundleSize; // The number of NFTs in each minted bundle.
    uint256 public price; // The ETH price for minting a bundle.

    IKondux public kNFT; // Interface to interact with the Kondux NFT contract for NFT operations.
    IKondux public foundersPass; // Interface for the founders pass contract, allowing for special minting conditions.
    ITreasury public treasury; // Interface to interact with the treasury contract for financial transactions.
    IKonduxERC20 public paymentToken; // Interface for the ERC20 token used for minting payments.
    IUniswapV2Pair public uniswapPair; // Interface for the Uniswap V2 pair contract for token swaps.
    address public WETH; // The address of the WETH token contract.

    uint8 private tokenDecimalsCached; // Cached decimals of the ERC20 token.

    bool public foundersPassActive; // Controls whether founders pass minting is active.

    // Events for tracking contract state changes and interactions.
    event BundleMinted(address indexed minter, uint256[] tokenIds);
    event TreasuryChanged(address indexed treasury);
    event FoundersPassChanged(address indexed foundersPass);
    event KNFTChanged(address indexed kNFT);
    event BundleSizeChanged(uint16 bundleSize);
    event PriceChanged(uint256 price);
    event Paused(bool paused);
    event PublicMintActive(bool active);
    event FoundersPassMintActive(bool active);
    event AdminGranted(address indexed admin);
    event TokensWithdrawn(address indexed admin, address indexed token, uint256 amount);
    event ETHWithdrawn(address indexed admin, uint256 amount);
    event ConfigurationsUpdated(
        uint256 price,
        uint16 bundleSize,
        address kNFT,
        address foundersPass,
        address treasury,
        address paymentToken,
        address uniswapPair,
        address WETH
    );

    // Modifiers
    /**
     * @dev Ensures a function is only callable when the contract is not paused.
     */
    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /**
     * @dev Restricts a function's access to users with the admin role.
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    // Constructor to initialize contract addresses and settings
    constructor(
        address _kNFT,
        address _foundersPass,
        address _treasury,
        address _paymentToken,
        address _uniswapPair,
        address _WETH
    ) {
        require(_kNFT != address(0), "Invalid kNFT address");
        require(_foundersPass != address(0), "Invalid foundersPass address");
        require(_treasury != address(0), "Invalid treasury address");
        require(_paymentToken != address(0), "Invalid paymentToken address");
        require(_uniswapPair != address(0), "Invalid uniswapPair address");
        require(_WETH != address(0), "Invalid WETH address");

        kNFT = IKondux(_kNFT);
        foundersPass = IKondux(_foundersPass);
        treasury = ITreasury(_treasury);
        paymentToken = IKonduxERC20(_paymentToken);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _WETH;
        price = 0.25 ether;
        bundleSize = 5;
        paused = true;
        foundersPassActive = true;

        // Cache token decimals for gas optimization
        tokenDecimalsCached = paymentToken.decimals();

        // Grant admin role to the deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Toggles the paused state of minting operations.
     * @dev Can only be executed by an admin. Emits a `Paused` event reflecting the new state.
     * @param _paused Boolean indicating the desired paused state.
     */
    function setPaused(bool _paused) public onlyAdmin {
        paused = _paused;
        emit Paused(_paused);
    }

    /**
     * @notice Mints a bundle of NFTs if minting is active and sufficient ERC20 tokens are sent.
     * @dev Validates the token amount against the current ETH price, transfers tokens to the treasury, and mints the NFT bundle.
     * Requires the contract to not be paused.
     * @return tokenIds Array of minted token IDs.
     */
    function publicMint() public nonReentrant notPaused returns (uint256[] memory) {
        uint256 tokensRequired = _calculateTokenAmount(price);
        require(
            paymentToken.allowance(msg.sender, address(this)) >= tokensRequired,
            "Insufficient token allowance"
        );
        require(
            paymentToken.balanceOf(msg.sender) >= tokensRequired,
            "Insufficient token balance"
        );

        // Transfer tokens from user to treasury
        bool success = paymentToken.transferFrom(msg.sender, address(treasury), tokensRequired);
        require(success, "Token transfer failed");

        // Mint the NFT bundle
        uint256[] memory tokenIds = _mintBundle(bundleSize);
        emit BundleMinted(msg.sender, tokenIds);
        return tokenIds;
    }

    /**
     * @notice Updates the address of the Kondux NFT contract.
     * @dev Admin-only function to change the contract address for managing Kondux NFT operations. Validates the new address before updating and emits a `KNFTChanged` event on success.
     * @param _kNFT The new Kondux NFT contract address.
     */
    function setKNFT(address _kNFT) public onlyAdmin {
        require(_kNFT != address(0), "KNFT address is not set");
        kNFT = IKondux(_kNFT);
        emit KNFTChanged(_kNFT);
    }

    /**
     * @notice Updates the address of the treasury contract.
     * @dev Admin-only function to change the contract address for managing treasury operations. Validates the new address before updating and emits a `TreasuryChanged` event on success.
     * @param _treasury The new treasury contract address.
     */
    function setTreasury(address _treasury) public onlyAdmin {
        require(_treasury != address(0), "Treasury address is not set");
        treasury = ITreasury(_treasury);
        emit TreasuryChanged(_treasury);
    }

    /**
     * @notice Updates the address of the founders pass contract.
     * @dev Admin-only function to change the contract address for managing founders pass operations. Validates the new address before updating and emits a `FoundersPassChanged` event on success.
     * @param _foundersPass The new founders pass contract address.
     */
    function setFoundersPass(address _foundersPass) public onlyAdmin {
        require(_foundersPass != address(0), "Founders pass address is not set");
        foundersPass = IKondux(_foundersPass);
        emit FoundersPassChanged(_foundersPass);
    }

    /**
     * @notice Updates the minting price for an NFT bundle.
     * @dev Admin-only function to adjust the ETH price required to mint an NFT bundle. Validates the new price before applying the change and emits a `PriceChanged` event on success.
     * @param _price The new minting price in ETH.
     */
    function setPrice(uint256 _price) public onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        price = _price;
        emit PriceChanged(_price);
    }

    /**
     * @notice Adjusts the size of the NFT bundle that can be minted at once.
     * @dev Admin-only function to set the number of NFTs included in a single mint operation. Validates the new size for practical limits and emits a `BundleSizeChanged` event on update.
     * @param _bundleSize The new bundle size, within set boundaries.
     */
    function setBundleSize(uint16 _bundleSize) public onlyAdmin {
        require(_bundleSize > 0, "Bundle size must be greater than 0");
        require(_bundleSize <= 15, "Bundle size must be less than or equal to 15");
        bundleSize = _bundleSize;
        emit BundleSizeChanged(_bundleSize);
    }

    /**
     * @notice Grants the admin role to a specified address.
     * @dev Can be executed only by an existing admin. Ensures that the target address is not already an admin and is not the zero address before granting the role.
     * @param _admin The address to be granted admin privileges.
     */
    function setAdmin(address _admin) public onlyAdmin {
        require(_admin != address(0), "Admin address is not set");
        require(!hasRole(DEFAULT_ADMIN_ROLE, _admin), "Address already has admin role");
        grantRole(DEFAULT_ADMIN_ROLE, _admin);
        emit AdminGranted(_admin);
    }

    /**
     * @notice Sets the active state for founders pass minting.
     * @dev Admin-only function to toggle the active state of minting NFTs with founders passes. Emits a `FoundersPassMintActive` event reflecting the new state.
     * @param _active Boolean indicating the desired active state.
     */
    function setFoundersPassMintActive(bool _active) public onlyAdmin {
        foundersPassActive = _active;
        emit FoundersPassMintActive(_active);
    }

    // Getter functions provide external visibility into the contract's state without modifying it.

    /**
     * @notice Returns the address of the Kondux NFT contract.
     * @return The current address interfaced by this contract for Kondux NFT operations.
     */
    function getKNFT() public view returns (address) {
        return address(kNFT);
    }

    /**
     * @notice Returns the address of the treasury contract.
     * @return The current treasury contract address for financial transactions related to minting.
     */
    function getTreasury() public view returns (address) {
        return address(treasury);
    }

    /**
     * @notice Calculates the number of ERC20 tokens required for a given ETH amount based on Uniswap V2 pair reserves.
     * @param ethAmount The amount of ETH to convert to ERC20 tokens (in wei).
     * @return tokenAmount The equivalent amount of ERC20 tokens.
     */
    function getTokenAmountForETH(uint256 ethAmount) public view returns (uint256 tokenAmount) {
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();
        tokenAmount = _calculateTokenAmount(ethAmount, reserveETH, reserveToken, tokenDecimalsCached);
    }

    /**
     * @notice Helper function to get the current price of the token in ETH.
     * @return priceInETH The price of one ERC20 token in ETH (in wei).
     */
    function getTokenPriceInETH() public view returns (uint256 priceInETH) {
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();
        priceInETH = _calculatePriceInETH(reserveETH, reserveToken, tokenDecimalsCached);
    }

    // Internal helper functions

    /**
     * @notice Fetches and returns the reserves for ETH and the ERC20 token from the Uniswap pair.
     * @return reserveETH The reserve amount of ETH in the pair.
     * @return reserveToken The reserve amount of ERC20 tokens in the pair.
     */
    function _getReserves() internal view returns (uint112 reserveETH, uint112 reserveToken) {
        (uint112 reserve0, uint112 reserve1, ) = uniswapPair.getReserves();
        address token0 = uniswapPair.token0();
        address token1 = uniswapPair.token1();

        if (token0 == WETH) {
            reserveETH = reserve0;
            reserveToken = reserve1;
        } else {
            reserveETH = reserve1;
            reserveToken = reserve0;
        }

        require(reserveETH > 0 && reserveToken > 0, "Invalid reserves");
    }

    /**
     * @notice Calculates the number of ERC20 tokens required for a given ETH amount based on reserves and token decimals.
     * @param ethAmount The amount of ETH to convert to ERC20 tokens.
     * @param reserveETH The reserve amount of ETH in the pair.
     * @param reserveToken The reserve amount of ERC20 tokens in the pair.
     * @param tokenDecimals The number of decimals the ERC20 token uses.
     * @return tokenAmount The equivalent amount of ERC20 tokens.
     */
    function _calculateTokenAmount(
        uint256 ethAmount,
        uint112 reserveETH,
        uint112 reserveToken,
        uint8 tokenDecimals
    ) internal pure returns (uint256 tokenAmount) {
        // Formula: tokenAmount = (ethAmount * reserveToken * 10**tokenDecimals) / (reserveETH * 1e18)
        // To maintain precision, we rearrange the calculation to avoid loss of precision.

        // Convert reserveETH to wei if not already (assuming it's in wei)
        // Assuming ethAmount is in wei.

        // Calculate the number of tokens: (ethAmount * reserveToken) / reserveETH
        // Adjust for token decimals
        if (tokenDecimals < 18) {
            tokenAmount = (ethAmount * reserveToken * (10 ** tokenDecimals)) / (reserveETH * 1e18);
        } else if (tokenDecimals > 18) {
            uint256 decimalDifference = tokenDecimals - 18;
            tokenAmount = (ethAmount * reserveToken * (10 ** decimalDifference)) / reserveETH;
        } else {
            // tokenDecimals == 18
            tokenAmount = (ethAmount * reserveToken) / reserveETH;
        }
    }

    /**
     * @notice Calculates the price of one ERC20 token in ETH based on reserves and token decimals.
     * @param reserveETH The reserve amount of ETH in the pair.
     * @param reserveToken The reserve amount of ERC20 tokens in the pair.
     * @param tokenDecimals The number of decimals the ERC20 token uses.
     * @return priceInETH The price of one ERC20 token in ETH (in wei).
     */
    function _calculatePriceInETH(
        uint112 reserveETH,
        uint112 reserveToken,
        uint8 tokenDecimals
    ) internal pure returns (uint256 priceInETH) {
        // Formula: priceInETH = (reserveETH * 1e18) / (reserveToken * 10**tokenDecimals)
        // Adjust based on token decimals to maintain precision.

        if (tokenDecimals < 18) {
            priceInETH = (uint256(reserveETH) * 1e18) / (uint256(reserveToken) * (10 ** tokenDecimals));
        } else if (tokenDecimals > 18) {
            uint256 decimalDifference = tokenDecimals - 18;
            priceInETH = (uint256(reserveETH) * 1e18) / (uint256(reserveToken) * (10 ** decimalDifference));
        } else {
            // tokenDecimals == 18
            priceInETH = (uint256(reserveETH) * 1e18) / uint256(reserveToken);
        }
    }

    /**
     * @dev Mints a specified number of NFTs to the sender's address. Each NFT minted is part of the bundle and is assigned a consecutive token ID.
     * @param _bundleSize The number of NFTs to mint in the bundle.
     * @return tokenIds An array of the minted NFT token IDs.
     */
    function _mintBundle(uint16 _bundleSize) internal returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_bundleSize);
        for (uint16 i = 0; i < _bundleSize; i++) {
            tokenIds[i] = kNFT.safeMint(msg.sender, 0); // The second parameter could be a metadata identifier or similar.
        }
        return tokenIds;
    }

    // Additional functions to manage contract state (e.g., pause, activate) can be added here

    /**
     * @notice Emergency function to withdraw ERC20 tokens from the contract.
     * @dev Can only be executed by an admin. This function is intended for emergency situations.
     * @param _token The address of the ERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function emergencyWithdrawTokens(address _token, uint256 _amount) external onlyAdmin {
        require(_token != address(0), "Invalid token address");
        IERC20 token = IERC20(_token);
        uint256 contractBalance = token.balanceOf(address(this));
        require(_amount <= contractBalance, "Insufficient token balance");
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Token transfer failed");
        emit TokensWithdrawn(msg.sender, _token, _amount);
    }

    /**
     * @notice Emergency function to withdraw ETH from the contract.
     * @dev Can only be executed by an admin. This function is intended for emergency situations.
     * @param _amount The amount of ETH to withdraw (in wei).
     */
    function emergencyWithdrawETH(uint256 _amount) external onlyAdmin {
        uint256 contractETHBalance = address(this).balance;
        require(_amount <= contractETHBalance, "Insufficient ETH balance");
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "ETH transfer failed");
        emit ETHWithdrawn(msg.sender, _amount);
    }

    /**
     * @notice Batch update multiple configuration parameters.
     * @dev Admin-only function to update multiple settings in a single transaction. Emits a `ConfigurationsUpdated` event.
     * @param _price The new minting price in ETH.
     * @param _bundleSize The new bundle size.
     * @param _kNFT The new Kondux NFT contract address.
     * @param _foundersPass The new founders pass contract address.
     * @param _treasury The new treasury contract address.
     * @param _paymentTokenAddr The new payment token address.
     * @param _uniswapPair The new Uniswap pair address.
     * @param _WETH The new WETH address.
     */
    function batchUpdateConfigurations(
        uint256 _price,
        uint16 _bundleSize,
        address _kNFT,
        address _foundersPass,
        address _treasury,
        address _paymentTokenAddr,
        address _uniswapPair,
        address _WETH
    ) external onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        require(_bundleSize > 0 && _bundleSize <= 15, "Invalid bundle size");
        require(_kNFT != address(0), "Invalid kNFT address");
        require(_foundersPass != address(0), "Invalid foundersPass address");
        require(_treasury != address(0), "Invalid treasury address");
        require(_paymentTokenAddr != address(0), "Invalid paymentToken address");
        require(_uniswapPair != address(0), "Invalid uniswapPair address");
        require(_WETH != address(0), "Invalid WETH address");

        price = _price;
        bundleSize = _bundleSize;
        kNFT = IKondux(_kNFT);
        foundersPass = IKondux(_foundersPass);
        treasury = ITreasury(_treasury);
        paymentToken = IKonduxERC20(_paymentTokenAddr);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _WETH;

        // Update cached token decimals
        tokenDecimalsCached = paymentToken.decimals();

        emit ConfigurationsUpdated(
            _price,
            _bundleSize,
            _kNFT,
            _foundersPass,
            _treasury,
            _paymentTokenAddr,
            _uniswapPair,
            _WETH
        );
    }

    /**
     * @notice Assigns a specific role to an address.
     * @dev Admin-only function to assign roles for more granular access control.
     * @param role The bytes32 identifier of the role.
     * @param account The address to be assigned the role.
     */
    function grantRoleTo(bytes32 role, address account) external onlyAdmin {
        require(account != address(0), "Cannot grant role to zero address");
        grantRole(role, account);
        // Optionally, emit a custom event if desired
    }

    /**
     * @notice Revokes a specific role from an address.
     * @dev Admin-only function to revoke roles for more granular access control.
     * @param role The bytes32 identifier of the role.
     * @param account The address from which the role will be revoked.
     */
    function revokeRoleFrom(bytes32 role, address account) external onlyAdmin {
        require(account != address(0), "Cannot revoke role from zero address");
        revokeRole(role, account);
        // Optionally, emit a custom event if desired
    }

    /**
     * @notice Receives ETH sent directly to the contract.
     * @dev Allows the contract to accept ETH. This could be useful for certain operations or in emergency scenarios.
     */
    receive() external payable {}

    /**
     * @notice Fallback function to handle calls to non-existent functions.
     * @dev Ensures that any unexpected calls are gracefully handled.
     */
    fallback() external payable {}
}
