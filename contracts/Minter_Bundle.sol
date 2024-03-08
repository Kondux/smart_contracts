// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import "./interfaces/IKondux.sol";
import "./interfaces/ITreasury.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// import "hardhat/console.sol";

/// @title MinterBundle
/// @notice A smart contract for managing the minting of NFT bundles, setting prices, and interacting with the treasury.
/// @dev Inherits from OpenZeppelin's AccessControl for role management.
contract MinterBundle is AccessControl {

    /// @notice The size of each NFT bundle to be minted.
    uint16 public bundleSize;

    /// @notice The price in ETH for minting an NFT bundle.
    uint256 public price;

    /// @notice Boolean flag to indicate whether minting is paused or active.
    bool public paused;

    /// @notice Interface to interact with Kondux NFT contract.
    IKondux public kNFT;

    /// @notice Iterface to interact with the kBOX NFT contract.
    IKondux public kBox;

    /// @notice Interface to interact with the treasury contract.
    ITreasury public treasury;

    // Events
    event BundleMinted(address indexed minter, uint256[] tokenIds);
    event TreasuryChanged(address indexed treasury);
    event KNFTChanged(address indexed kNFT);
    event PriceChanged(uint256 price);
    event BundleSizeChanged(uint16 bundleSize);
    event Paused(bool paused);

    /// @notice Constructor to initialize the MinterBundle contract.
    /// @param _kNFT The address of the Kondux NFT contract.
    /// @param _treasury The address of the treasury contract.
    constructor(address _kNFT, address _kBox, address _treasury) {
        kNFT = IKondux(_kNFT);
        kBox = IKondux(_kBox);
        treasury = ITreasury(_treasury);
        price = 0.25 ether;
        bundleSize = 5;
        paused = false;
        // console.log(address(kNFT));  
        
        // Grant admin role to the message sender
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Sets the paused state of the contract.
    /// @dev Can only be called by an admin.
    /// @param _paused The new paused state.
    function setPaused(bool _paused) public onlyAdmin {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Function to mint a bundle of NFTs if the contract is active.
    /// @dev Requires sufficient ETH sent and calls the internal mint function.
    /// @return tokenIds The array of minted token IDs.
    function publicMint() public payable isActive returns (uint256[] memory){
        require(msg.value >= price, "Not enough ETH sent");
        treasury.depositEther{ value: msg.value }();
        uint256[] memory tokenIds = _mintBundle();
        emit BundleMinted(msg.sender, tokenIds);
        return tokenIds;
    }

    /// @notice Function to burn a kBox and mint a bundle of NFTs if the contract is active. 
    /// @dev Requires a kBox sent and calls the internal mint function. It burns a kBox and mints a bundle of NFTs.
    /// @return tokenIds The array of minted token IDs.
    function publicMintWithBox(uint256 _kBoxId) public isActive returns (uint256[] memory){
        require(kBox.ownerOf(_kBoxId) == msg.sender, "You are not the owner of this kBox");
        require(kBox.getApproved(_kBoxId) == address(this), "This contract is not approved to burn this kBox");
        kBox.burn(_kBoxId);
        uint256[] memory tokenIds = _mintBundle();
        emit BundleMinted(msg.sender, tokenIds);
        return tokenIds;
    }

    /// @notice Sets the kBox NFT contract address.
    /// @dev Can only be called by an admin, requires non-zero address.
    /// @param _kBox The new kBox address.
    function setKBox(address _kBox) public onlyAdmin {
        require(_kBox != address(0), "kBox address is not set");
        kBox = IKondux(_kBox);
        emit KNFTChanged(_kBox);
    }

    /// @notice Sets the treasury contract address.
    /// @dev Can only be called by an admin, requires non-zero address.
    /// @param _treasury The new treasury address.
    function setTreasury(address _treasury) public onlyAdmin {
        require(_treasury != address(0), "Treasury address is not set");
        treasury = ITreasury(_treasury);
        emit TreasuryChanged(_treasury);
    }

    /// @notice Sets the Kondux NFT contract address.
    /// @dev Can only be called by an admin, requires non-zero address.
    /// @param _kNFT The new KNFT address.
    function setKNFT(address _kNFT) public onlyAdmin {
        require(_kNFT != address(0), "KNFT address is not set");
        kNFT = IKondux(_kNFT);
        emit KNFTChanged(_kNFT);
    }

    /// @notice Sets the price for minting a bundle.
    /// @dev Can only be called by an admin, requires price > 0.
    /// @param _price The new price in ETH.
    function setPrice(uint256 _price) public onlyAdmin {
        require(_price > 0, "Price must be greater than 0");
        price = _price;
        emit PriceChanged(_price);
    }

    /// @notice Sets the size of the NFT bundle.
    /// @dev Can only be called by an admin, requires 0 < size <= 15.
    /// @param _bundleSize The new bundle size.
    function setBundleSize(uint16 _bundleSize) public onlyAdmin {
        require(_bundleSize > 0, "Bundle size must be greater than 0");
        require(_bundleSize <= 15, "Bundle size must be less than or equal to 15");
        bundleSize = _bundleSize;
        emit BundleSizeChanged(_bundleSize);
    }

    /// @notice Grants admin role to the specified address.
    /// @dev Can only be called by an admin, requires non-zero address and address not already an admin.
    /// @param _admin The address to be granted the admin role.
    function setAdmin(address _admin) public onlyAdmin {
        require(_admin != address(0), "Admin address is not set");
        require(!hasRole(DEFAULT_ADMIN_ROLE, _admin), "Address already has admin role");
        grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    // ** GETTERS ** //

    /// @notice Get the address of the Kondux NFT contract.
    /// @return The address of the Kondux NFT contract.
    function getKNFT() public view returns (address) {
        return address(kNFT);
    }

    /// @notice Get the address of the kBox NFT contract.
    /// @return The address of the kBox NFT contract.
    function getKBox() public view returns (address) {
        return address(kBox);
    }

    /// @notice Get the address of the treasury contract.
    /// @return The address of the treasury contract.
    function getTreasury() public view returns (address) {
        return address(treasury);
    }

    // ** INTERNAL FUNCTIONS **

    /// @notice Internal function to mint a bundle of NFTs.
    /// @dev Mints 'bundleSize' number of NFTs.
    /// @return tokenIds The array of minted token IDs.
    function _mintBundle() internal returns (uint256[] memory){
        uint256[] memory tokenIds = new uint256[](bundleSize);
        for (uint16 i = 0; i < bundleSize; i++) {
            tokenIds[i] = kNFT.safeMint(msg.sender, 0);
        }
        return tokenIds;
    }

    // ** MODIFIERS **

    /// @notice Modifier to require the contract to be active (not paused).
    modifier isActive() {
        require(!paused, "Pausable: paused");
        _;
    }

    /// @notice Modifier to restrict function access to only admin roles.
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT Access Control: only admin");
        _;
    }
}