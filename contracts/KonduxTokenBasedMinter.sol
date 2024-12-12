// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Import Interfaces
import "./interfaces/IKondux.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IKonduxERC20.sol";

// Import OpenZeppelin Contracts
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract KonduxTokenBasedMinter is AccessControl, ReentrancyGuard {
    using Math for uint256;

    // State Variables

    /// @notice Indicates whether minting operations are currently paused.
    bool public paused;

    /// @notice The number of NFTs in each minted bundle.
    uint16 public bundleSize;

    /// @notice The full ETH price for minting a bundle of NFTs.
    uint256 public fullPrice;

    /// @notice The discounted ETH price for minting a bundle of NFTs (e.g., for certain users).
    uint256 public discountPrice;

    /// @notice The discounted ETH price for minting a bundle if the minter holds a Founder's Pass NFT.
    uint256 public founderDiscountPrice;

    /// @notice The Kondux NFT contract interface used for minting NFTs.
    IKondux public kNFT;

    /// @notice The Founders Pass NFT contract interface. Holding this pass may grant minting discounts.
    IERC721 public foundersPass;

    /// @notice The Treasury contract interface where funds are directed.
    ITreasury public treasury;

    /// @notice The ERC20 token interface used as a payment method for minting.
    IKonduxERC20 public paymentToken;

    /// @notice The Uniswap V2 Pair interface used to determine token/ETH price ratios.
    IUniswapV2Pair public uniswapPair;

    /// @notice The WETH token contract address used in the Uniswap Pair.
    address public WETH;

    /// @dev Cached value of the payment token decimals for gas optimization.
    uint8 private tokenDecimalsCached;

    /// @notice Indicates whether the special Founder’s Pass minting discount is active.
    bool public foundersPassActive;

    // Events

    /// @notice Emitted when a bundle of NFTs is minted.
    /// @param minter The address that minted the bundle.
    /// @param tokenIds The IDs of the newly minted NFTs.
    event BundleMinted(address indexed minter, uint256[] tokenIds);

    /// @notice Emitted when the Treasury contract address is updated.
    /// @param treasury The new treasury address.
    event TreasuryChanged(address indexed treasury);

    /// @notice Emitted when the Founders Pass contract address is updated.
    /// @param foundersPass The new Founders Pass contract address.
    event FoundersPassChanged(address indexed foundersPass);

    /// @notice Emitted when the Kondux NFT contract address is updated.
    /// @param kNFT The new Kondux NFT contract address.
    event KNFTChanged(address indexed kNFT);

    /// @notice Emitted when the bundle size is updated.
    /// @param bundleSize The new bundle size.
    event BundleSizeChanged(uint16 bundleSize);

    /// @notice Emitted when any of the minting prices (full/discount/founder discount) is changed.
    /// @param price The new price that was set.
    event PriceChanged(uint256 price);

    /// @notice Emitted when the contract pause state changes.
    /// @param paused The new paused state.
    event Paused(bool paused);

    /// @notice Emitted when public minting is enabled or disabled.
    /// @param active Indicates if public minting is active.
    event PublicMintActive(bool active);

    /// @notice Emitted when Founders Pass minting is enabled or disabled.
    /// @param active Indicates if Founders Pass minting is active.
    event FoundersPassMintActive(bool active);

    /// @notice Emitted when a new admin is granted the DEFAULT_ADMIN_ROLE.
    /// @param admin The address of the new admin.
    event AdminGranted(address indexed admin);

    /// @notice Emitted when ERC20 tokens are withdrawn from the contract in an emergency.
    /// @param admin The admin who performed the withdrawal.
    /// @param token The token address withdrawn.
    /// @param amount The amount of tokens withdrawn.
    event TokensWithdrawn(address indexed admin, address indexed token, uint256 amount);

    /// @notice Emitted when ETH is withdrawn from the contract in an emergency.
    /// @param admin The admin who performed the withdrawal.
    /// @param amount The amount of ETH withdrawn.
    event ETHWithdrawn(address indexed admin, uint256 amount);

    /// @notice Emitted when multiple configurations are updated in a single transaction.
    event ConfigurationsUpdated(
        uint256 price,
        uint256 discountPrice,
        uint256 founderDiscountPrice,
        uint16 bundleSize,
        address kNFT,
        address foundersPass,
        address treasury,
        address paymentToken,
        address uniswapPair,
        address WETH
    );

    // Modifiers

    /// @notice Ensures a function is only callable when the contract is not paused.
    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /// @notice Restricts a function's access to callers with the admin role.
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    /// @notice Initializes the contract state and sets required external contract addresses.
    /// @dev All provided addresses must be non-zero. Initializes default prices, bundle size, and grants deployer admin role.
    /// @param _kNFT The Kondux NFT contract address.
    /// @param _foundersPass The Founders Pass NFT contract address.
    /// @param _treasury The Treasury contract address.
    /// @param _paymentToken The ERC20 token contract address used for payments.
    /// @param _uniswapPair The Uniswap V2 Pair contract address for price calculations.
    /// @param _WETH The WETH contract address used in the Uniswap pair.
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
        foundersPass = IERC721(_foundersPass); 
        treasury = ITreasury(_treasury);
        paymentToken = IKonduxERC20(_paymentToken);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _WETH;
        fullPrice = 0.25 ether;
        discountPrice = 0.225 ether;
        founderDiscountPrice = 0.2 ether;
        bundleSize = 5;
        paused = true;
        foundersPassActive = true;

        // Cache token decimals for gas optimization
        tokenDecimalsCached = paymentToken.decimals();

        // Grant admin role to the deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Sets the paused state of the contract's minting operations.
     * @dev Only callable by an admin. When paused, all minting functions will revert.
     * @param _paused Boolean indicating the desired paused state.
     */
    function setPaused(bool _paused) public onlyAdmin {
        paused = _paused;
        emit Paused(_paused);
    }

    /**
     * @notice Allows a user to mint a bundle of NFTs using the payment token.
     * @dev Checks for allowance and balance of payment tokens, calculates the required token amount
     *      from the ETH price based on the Uniswap reserves, and transfers tokens to the treasury.
     *      Mints `bundleSize` NFTs to the caller. Reverts if paused.
     * @return tokenIds An array of token IDs for the newly minted NFTs.
     */
    function publicMint() public nonReentrant notPaused returns (uint256[] memory) {
        // Fetch current reserves
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();

        uint256 _userPrice = discountPrice;

        // If foundersPass is active and user has at least one founders pass, apply founder discount price
        if (foundersPassActive && foundersPass.balanceOf(msg.sender) > 0) {
            _userPrice = founderDiscountPrice;
        }

        // Calculate the number of tokens required based on ETH price
        uint256 tokensRequired = _calculateTokenAmount(_userPrice, reserveETH, reserveToken); 

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
     * @notice Updates the Kondux NFT contract address.
     * @dev Only callable by an admin. The provided address must be non-zero.
     * @param _kNFT The new Kondux NFT contract address.
     */
    function setKNFT(address _kNFT) public onlyAdmin {
        require(_kNFT != address(0), "KNFT address is not set");
        kNFT = IKondux(_kNFT);
        emit KNFTChanged(_kNFT);
    }

    /**
     * @notice Updates the Treasury contract address.
     * @dev Only callable by an admin. The provided address must be non-zero.
     * @param _treasury The new Treasury contract address.
     */
    function setTreasury(address _treasury) public onlyAdmin {
        require(_treasury != address(0), "Treasury address is not set");
        treasury = ITreasury(_treasury);
        emit TreasuryChanged(_treasury);
    }

    /**
     * @notice Updates the Founders Pass contract address.
     * @dev Only callable by an admin. The provided address must be non-zero.
     * @param _foundersPass The new Founders Pass contract address.
     */
    function setFoundersPass(address _foundersPass) public onlyAdmin {
        require(_foundersPass != address(0), "Founders pass address is not set");
        foundersPass = IERC721(_foundersPass);
        emit FoundersPassChanged(_foundersPass);
    }

    /**
     * @notice Sets whether the Founders Pass discount is active.
     * @dev Only callable by an admin.
     * @param _active Boolean indicating the desired state of the Founders Pass discount.
     */
    function setFoundersPassActive(bool _active) public onlyAdmin {
        foundersPassActive = _active;
        emit FoundersPassMintActive(_active);
    }

    /**
     * @notice Updates the full (non-discounted) mint price for a bundle.
     * @dev Only callable by an admin. The price must be greater than zero.
     * @param _price The new full bundle minting price in ETH.
     */
    function setFullPrice(uint256 _price) public onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        fullPrice = _price;
        emit PriceChanged(_price);
    }

    /**
     * @notice Updates the discounted mint price for a bundle.
     * @dev Only callable by an admin. The price must be greater than zero.
     * @param _price The new discounted bundle minting price in ETH.
     */
    function setDiscountPrice(uint256 _price) public onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        discountPrice = _price;
        emit PriceChanged(_price);
    }

    /**
     * @notice Updates the Founder-specific discounted mint price for a bundle.
     * @dev Only callable by an admin. The price must be greater than zero.
     * @param _price The new founder discount bundle minting price in ETH.
     */
    function setFounderDiscountPrice(uint256 _price) public onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        founderDiscountPrice = _price;
        emit PriceChanged(_price);
    }

    /**
     * @notice Updates the number of NFTs in each minted bundle.
     * @dev Only callable by an admin. The bundle size must be between 1 and 15.
     * @param _bundleSize The new bundle size.
     */
    function setBundleSize(uint16 _bundleSize) public onlyAdmin {
        require(_bundleSize > 0, "Bundle size must be greater than 0");
        require(_bundleSize <= 15, "Bundle size must be less than or equal to 15");
        bundleSize = _bundleSize;
        emit BundleSizeChanged(_bundleSize);
    }

    /**
     * @notice Grants the admin role to a specified address.
     * @dev Only callable by an admin. The new admin address must be non-zero and not already an admin.
     * @param _admin The address to be granted admin privileges.
     */
    function setAdmin(address _admin) public onlyAdmin {
        require(_admin != address(0), "Admin address is not set");
        require(!hasRole(DEFAULT_ADMIN_ROLE, _admin), "Address already has admin role");
        grantRole(DEFAULT_ADMIN_ROLE, _admin);
        emit AdminGranted(_admin);
    }

    /**
     * @notice Returns the address of the Kondux NFT contract.
     * @dev This is a simple getter function for external convenience.
     * @return The current Kondux NFT contract address.
     */
    function getKNFT() public view returns (address) {
        return address(kNFT);
    }

    /**
     * @notice Returns the address of the Treasury contract.
     * @dev This is a simple getter function for external convenience.
     * @return The current treasury contract address.
     */
    function getTreasury() public view returns (address) {
        return address(treasury);
    }

    /**
     * @notice Calculates how many payment tokens are required for a given amount of ETH.
     * @dev Uses Uniswap V2 pair reserves to determine price. The formula is tokens = (ethAmount * reserveToken) / reserveETH.
     * @param _ethAmount The amount of ETH (in wei) to convert into payment tokens.
     * @return tokenAmount The equivalent amount of ERC20 tokens needed.
     */
    function getTokenAmountForETH(uint256 _ethAmount) public view returns (uint256 tokenAmount) {
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();
        tokenAmount = _calculateTokenAmount(_ethAmount, reserveETH, reserveToken); 
    }

    /**
     * @notice Calculates the price of one payment token in terms of ETH, given current reserves.
     * @dev priceInETH = (reserveETH * 1e18) / reserveToken.
     * @return priceInETH The price of one payment token in wei of ETH.
     */
    function getTokenPriceInETH() public view returns (uint256 priceInETH) {
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();
        priceInETH = _calculatePriceInETH(reserveETH, reserveToken);
    }

    /**
     * @notice Retrieves the current reserve amounts of ETH and ERC20 tokens from the Uniswap pair.
     * @dev Public getter function that relies on internal logic to determine which reserve corresponds to ETH and which corresponds to the token.
     * @return reserveETH The reserve amount of ETH in the pair.
     * @return reserveToken The reserve amount of the ERC20 token in the pair.
     */
    function getReserves() public view returns (uint112 reserveETH, uint112 reserveToken) {
        return _getReserves();
    }

    /**
     * @notice Emergency function to withdraw ERC20 tokens from the contract.
     * @dev Only callable by an admin. This is an emergency function in case tokens accidentally get stuck.
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
     * @dev Only callable by an admin. This is an emergency function in case ETH accidentally gets stuck.
     * @param _amount The amount of ETH (in wei) to withdraw.
     */
    function emergencyWithdrawETH(uint256 _amount) external onlyAdmin {
        uint256 contractETHBalance = address(this).balance;
        require(_amount <= contractETHBalance, "Insufficient ETH balance");
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "ETH transfer failed");
        emit ETHWithdrawn(msg.sender, _amount);
    }

    /**
     * @notice Batch update multiple configuration parameters in a single transaction.
     * @dev Only callable by an admin. All addresses must be non-zero and prices must be greater than zero.
     * @param _price The new full price.
     * @param _discountPrice The new discount price.
     * @param _founderDiscountPrice The new founder discount price.
     * @param _bundleSize The new bundle size.
     * @param _kNFT The new Kondux NFT contract address.
     * @param _foundersPass The new Founders Pass contract address.
     * @param _treasury The new Treasury contract address.
     * @param _paymentTokenAddr The new payment token contract address.
     * @param _uniswapPair The new Uniswap pair contract address.
     * @param _WETH The new WETH contract address.
     */
    function batchUpdateConfigurations(
        uint256 _price,
        uint256 _discountPrice,
        uint256 _founderDiscountPrice,
        uint16 _bundleSize,
        address _kNFT,
        address _foundersPass,
        address _treasury,
        address _paymentTokenAddr,
        address _uniswapPair,
        address _WETH
    ) external onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        require(_discountPrice > 0, "Discount price must be greater than 0");
        require(_founderDiscountPrice > 0, "Founder discount price must be greater than 0");
        require(_bundleSize > 0 && _bundleSize <= 15, "Invalid bundle size");
        require(_kNFT != address(0), "Invalid kNFT address");
        require(_foundersPass != address(0), "Invalid foundersPass address");
        require(_treasury != address(0), "Invalid treasury address");
        require(_paymentTokenAddr != address(0), "Invalid paymentToken address");
        require(_uniswapPair != address(0), "Invalid uniswapPair address");
        require(_WETH != address(0), "Invalid WETH address");

        fullPrice = _price;
        discountPrice = _discountPrice;
        founderDiscountPrice = _founderDiscountPrice;
        bundleSize = _bundleSize;
        kNFT = IKondux(_kNFT);
        foundersPass = IERC721(_foundersPass);
        treasury = ITreasury(_treasury);
        paymentToken = IKonduxERC20(_paymentTokenAddr);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _WETH;

        // Update cached token decimals
        tokenDecimalsCached = _getTokenDecimals(_paymentTokenAddr);

        emit ConfigurationsUpdated(
            _price,
            _discountPrice,
            _founderDiscountPrice,
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
     * @notice Grants a specific role to an account.
     * @dev Only callable by an admin. The account must be non-zero.
     * @param role The bytes32 identifier of the role (e.g., keccak256 hash).
     * @param account The account to be granted the role.
     */
    function grantRoleTo(bytes32 role, address account) external onlyAdmin {
        require(account != address(0), "Cannot grant role to zero address");
        grantRole(role, account);
        // Additional custom event can be emitted if needed.
    }

    /**
     * @notice Revokes a specific role from an account.
     * @dev Only callable by an admin. The account must be non-zero.
     * @param role The bytes32 identifier of the role.
     * @param account The account from which the role will be revoked.
     */
    function revokeRoleFrom(bytes32 role, address account) external onlyAdmin {
        require(account != address(0), "Cannot revoke role from zero address");
        revokeRole(role, account);
        // Additional custom event can be emitted if needed.
    }

    /**
     * @notice Helper function to retrieve token decimals from a given ERC20 token address.
     * @dev Tries a staticcall to `decimals()`; if it fails, defaults to 18.
     * @param _token The ERC20 token address.
     * @return decimals The number of decimals for the given token.
     */
    function getTokenDecimals(address _token) public view returns (uint8 decimals) {
        return _getTokenDecimals(_token);
    }

    /**
     * @notice Allows the contract to receive ETH directly.
     * @dev This may be useful for certain operations or emergency recoveries.
     */
    receive() external payable {}

    /**
     * @notice Fallback function to handle calls to non-existent functions.
     * @dev This ensures that any unexpected calls are handled gracefully.
     */
    fallback() external payable {}


    // Internal Helper Functions

    /**
     * @notice Retrieves and returns the reserves for ETH and the ERC20 token from the Uniswap pair.
     * @dev Internally determines which token is WETH and which is the payment token.
     * @return reserveETH The reserve amount of ETH in the pair.
     * @return reserveToken The reserve amount of the ERC20 token in the pair.
     */
    function _getReserves() internal view returns (uint112 reserveETH, uint112 reserveToken) {
        (uint112 reserve0, uint112 reserve1, ) = uniswapPair.getReserves();
        address token0 = uniswapPair.token0();

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
     * @notice Calculates the amount of payment tokens required for a given ETH amount using the current Uniswap reserves.
     * @dev Formula: tokens = (ethAmount * reserveToken) / reserveETH.
     * @param ethAmount The amount of ETH (in wei).
     * @param reserveETH The ETH reserves in the Uniswap pair.
     * @param reserveToken The token reserves in the Uniswap pair.
     * @return baseAmount The equivalent amount of tokens needed.
     */
    function _calculateTokenAmount(
        uint256 ethAmount,
        uint112 reserveETH,
        uint112 reserveToken
    ) internal pure returns (uint256 baseAmount) {
        baseAmount = Math.mulDiv(ethAmount, reserveToken, reserveETH);
    }

    /**
     * @notice Calculates the price of one payment token in ETH, given the current reserves.
     * @dev priceInETH = (reserveETH * 1e18) / reserveToken.
     * @param reserveETH The ETH reserves in the Uniswap pair.
     * @param reserveToken The token reserves in the Uniswap pair.
     * @return priceInETH The price of one payment token in wei of ETH.
     */
    function _calculatePriceInETH(
        uint112 reserveETH,
        uint112 reserveToken    
    ) internal pure returns (uint256 priceInETH) {
        priceInETH = (uint256(reserveETH) * 1e18) / uint256(reserveToken);
    }

    /**
     * @notice Mints a specified number of NFTs in a bundle to the caller.
     * @dev Mints `_bundleSize` NFTs and returns their newly assigned token IDs.
     * @param _bundleSize The number of NFTs to mint.
     * @return tokenIds An array containing the token IDs of the minted NFTs.
     */
    function _mintBundle(uint16 _bundleSize) internal returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_bundleSize);
        for (uint16 i = 0; i < _bundleSize; i++) {
            // The second parameter (0) can represent a placeholder or metadata ID as needed.
            tokenIds[i] = kNFT.safeMint(msg.sender, 0);
        }
        return tokenIds;
    }

    /**
     * @notice Attempts to retrieve the decimals of a given ERC20 token.
     * @dev Uses a low-level staticcall to `decimals()`. If it fails, defaults to 18.
     * @param token The ERC20 token address.
     * @return decimals The number of decimals of the token.
     */
    function _getTokenDecimals(address token) internal view returns (uint8 decimals) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            decimals = abi.decode(data, (uint8));
        } else {
            decimals = 18;
        }
    }
}
