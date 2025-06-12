// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Import Interfaces
import "./interfaces/IKondux.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IKonduxERC20.sol";

// OpenZeppelin Contracts
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title KonduxHybridMinter
 * @notice Minter contract allowing single kNFT minting paid in ETH or burned ERC20 tokens with configurable discounts,
 *         plus Merkle-based whitelist minting (one claim per address) for free, with independent pause controls.
 */
contract KonduxHybridMinter is AccessControl, ReentrancyGuard {
    using Math for uint256;

    // --- State Variables ---
    bool public paused;                        // Master pause
    bool public publicMintPaused;              // Pause public mint entirely
    bool public whitelistMintPaused;           // Pause whitelist mint entirely
    bool public tokenMintPaused;               // Pause ERC20 (token) payment mints
    bool public ethMintPaused;                 // Pause ETH payment mints
    uint256 public price;                      // ETH price per NFT
    uint256 public discountPercent;            // Discount percentage for token payments (0-100)
    IKondux public kNFT;
    ITreasury public treasury;
    IKonduxERC20 public paymentToken;
    IUniswapV2Pair public uniswapPair;
    address public WETH;
    bytes32 public merkleRoot;

    mapping(address => bool) public whitelistClaimed;
    uint8 private tokenDecimalsCached;

    // --- Events ---
    event PriceChanged(uint256 price);
    event DiscountPercentChanged(uint256 percent);
    event Paused(bool paused);
    event PublicMintPaused(bool paused);
    event WhitelistMintPaused(bool paused);
    event TokenMintPaused(bool paused);
    event EthMintPaused(bool paused);
    event KNFTChanged(address indexed kNFT);
    event TreasuryChanged(address indexed treasury);
    event MerkleRootChanged(bytes32 merkleRoot);
    event NFTMinted(address indexed minter, uint256 tokenId, bool paidWithToken);

    // --- Modifiers ---
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }
    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /**
     * @notice Constructor initializes roles, prices, and external contract references.
     */
    constructor(
        address _kNFT,
        address _treasury,
        address _paymentToken,
        address _uniswapPair,
        address _WETH,
        uint256 _price,
        uint256 _discountPercent,
        bytes32 _merkleRoot
    ) {
        require(_kNFT != address(0), "Invalid kNFT");
        require(_treasury != address(0), "Invalid treasury");
        require(_paymentToken != address(0), "Invalid paymentToken");
        require(_uniswapPair != address(0), "Invalid uniswapPair");
        require(_WETH != address(0), "Invalid WETH");
        require(_price > 0, "Price must be >0");
        require(_discountPercent <= 100, "Invalid discount");

        kNFT = IKondux(_kNFT);
        treasury = ITreasury(_treasury);
        paymentToken = IKonduxERC20(_paymentToken);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _WETH;

        price = _price;
        discountPercent = _discountPercent;
        merkleRoot = _merkleRoot;
        tokenDecimalsCached = paymentToken.decimals();

        paused = true;
        publicMintPaused = false;
        whitelistMintPaused = false;
        tokenMintPaused = false;
        ethMintPaused = false;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // --- Admin Functions ---
    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
        emit Paused(_paused);
    }

    function setPublicMintPaused(bool _paused) external onlyAdmin {
        publicMintPaused = _paused;
        emit PublicMintPaused(_paused);
    }

    function setWhitelistMintPaused(bool _paused) external onlyAdmin {
        whitelistMintPaused = _paused;
        emit WhitelistMintPaused(_paused);
    }

    function setTokenMintPaused(bool _paused) external onlyAdmin {
        tokenMintPaused = _paused;
        emit TokenMintPaused(_paused);
    }

    function setEthMintPaused(bool _paused) external onlyAdmin {
        ethMintPaused = _paused;
        emit EthMintPaused(_paused);
    }

    function setPrice(uint256 _price) external onlyAdmin {
        require(_price > 0, "Price must be >0");
        price = _price;
        emit PriceChanged(_price);
    }

    function setDiscountPercent(uint256 _discountPercent) external onlyAdmin {
        require(_discountPercent <= 100, "Invalid discount");
        discountPercent = _discountPercent;
        emit DiscountPercentChanged(_discountPercent);
    }

    function setKNFT(address _kNFT) external onlyAdmin {
        require(_kNFT != address(0), "Invalid kNFT");
        kNFT = IKondux(_kNFT);
        emit KNFTChanged(_kNFT);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "Invalid treasury");
        treasury = ITreasury(_treasury);
        emit TreasuryChanged(_treasury);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyAdmin {
        merkleRoot = _merkleRoot;
        emit MerkleRootChanged(_merkleRoot);
    }

    /**
     * @notice Public mint: single token; choose payment in ERC20 or ETH.
     * @param payWithToken true to pay with ERC20 (sent to zero address), false to pay in ETH.
     */
    function publicMint(bool payWithToken)
        external payable
        nonReentrant
        notPaused
        returns (uint256)
    {
        require(!publicMintPaused, "Public minting is paused");

        uint256 tokenId;
        if (payWithToken) {
            require(!tokenMintPaused, "Token mints are paused");
            (uint112 reserveETH, uint112 reserveToken) = _getReserves();
            uint256 tokensRequired = Math.mulDiv(price, reserveToken, reserveETH);
            if (discountPercent > 0) {
                tokensRequired = tokensRequired * (100 - discountPercent) / 100;
            }
            require(paymentToken.allowance(msg.sender, address(this)) >= tokensRequired, "Insufficient allowance");
            require(paymentToken.balanceOf(msg.sender) >= tokensRequired, "Insufficient balance");
            bool success = paymentToken.transferFrom(msg.sender, address(0), tokensRequired);
            require(success, "Token burn transfer failed");

            tokenId = kNFT.safeMint(msg.sender, 0);
            emit NFTMinted(msg.sender, tokenId, true);
        } else {
            require(!ethMintPaused, "ETH mints are paused");
            require(msg.value >= price, "Insufficient ETH");
            (bool sent, ) = address(treasury).call{value: price}("");
            require(sent, "ETH transfer failed");
            if (msg.value > price) {
                (bool refunded, ) = msg.sender.call{value: msg.value - price}("");
                require(refunded, "Refund failed");
            }

            tokenId = kNFT.safeMint(msg.sender, 0);
            emit NFTMinted(msg.sender, tokenId, false);
        }

        return tokenId;
    }

    /**
     * @notice Whitelist mint via Merkle proof; one free claim per address.
     */
    function whitelistMint(bytes32[] calldata proof)
        external
        nonReentrant
        notPaused
        returns (uint256)
    {
        require(!whitelistMintPaused, "Whitelist minting is paused");
        require(!whitelistClaimed[msg.sender], "Already claimed");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
        whitelistClaimed[msg.sender] = true;

        uint256 tokenId = kNFT.safeMint(msg.sender, 0);
        emit NFTMinted(msg.sender, tokenId, false);
        return tokenId;
    }

    // --- View Helpers ---
    function getTokenAmountForPrice() external view returns (uint256) {
        (uint112 reserveETH, uint112 reserveToken) = _getReserves();
        uint256 tokens = Math.mulDiv(price, reserveToken, reserveETH);
        if (discountPercent > 0) {
            tokens = tokens * (100 - discountPercent) / 100;
        }
        return tokens;
    }

    function _getReserves()
        internal view
        returns (uint112 reserveETH, uint112 reserveToken)
    {
        (uint112 r0, uint112 r1, ) = uniswapPair.getReserves();
        if (uniswapPair.token0() == WETH) {
            reserveETH = r0;
            reserveToken = r1;
        } else {
            reserveETH = r1;
            reserveToken = r0;
        }
        require(reserveETH > 0 && reserveToken > 0, "Invalid reserves");
    }

    // --- Fallbacks ---
    receive() external payable {}
    fallback() external payable {}
}
