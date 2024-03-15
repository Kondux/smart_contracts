// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import "./interfaces/IKondux.sol";
import "./interfaces/ITreasury.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title MinterBundle
 * @notice Manages the minting of NFT bundles, including setting prices, pausing/unpausing minting, and interacting with external contracts for NFT and treasury management. Designed to facilitate bulk operations for efficiency and convenience.
 * @dev Inherits from OpenZeppelin's AccessControl for comprehensive role management, enabling a robust permission system. Utilizes interfaces for external contract interactions, ensuring modularity and flexibility.
 */
contract MinterBundle is AccessControl {

    uint16 public bundleSize; // The number of NFTs in each minted bundle.
    uint256 public price; // The ETH price for minting a bundle.
    bool public paused; // Controls whether minting is currently allowed.

    IKondux public kNFT; // Interface to interact with the Kondux NFT contract for NFT operations.
    IKondux public kBox; // Interface for the kBOX NFT contract, allowing for special minting conditions.
    ITreasury public treasury; // Interface to interact with the treasury contract for financial transactions.


    // Events for tracking contract state changes and interactions.
    event BundleMinted(address indexed minter, uint256[] tokenIds);
    event TreasuryChanged(address indexed treasury);
    event KNFTChanged(address indexed kNFT);
    event KBoxChanged(address indexed kBox);
    event PriceChanged(uint256 price);
    event BundleSizeChanged(uint16 bundleSize);
    event Paused(bool paused);

    /**
     * @dev Sets initial contract state, including addresses of related contracts, default price, and bundle size. Grants admin role to the deployer for further administrative actions.
     * @param _kNFT Address of the Kondux NFT contract.
     * @param _kBox Address of the kBox NFT contract.
     * @param _treasury Address of the treasury contract.
     */
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
     * @notice Mints a bundle of NFTs if minting is active and sufficient ETH is sent.
     * @dev Validates the sent ETH amount against the current price, deposits the ETH to the treasury, and mints the NFT bundle. Requires the contract to not be paused.
     * @return tokenIds Array of minted token IDs.
     */
    function publicMint() public payable isActive returns (uint256[] memory){
        require(msg.value >= price, "Not enough ETH sent");
        treasury.depositEther{ value: msg.value }();
        uint256[] memory tokenIds = _mintBundle(bundleSize);
        emit BundleMinted(msg.sender, tokenIds);
        return tokenIds;
    }

    /**
     * @notice Burns a specified kBox and mints a bundle of NFTs as a special minting operation.
     * @dev Requires the sender to be the owner of the kBox and for the contract to be approved to burn the kBox. This function demonstrates an alternative minting pathway with additional prerequisites.
     * @param _kBoxId The ID of the kBox to be burned in exchange for minting a new NFT bundle.
     * @return tokenIds Array of minted token IDs.
     */
    function publicMintWithBox(uint256 _kBoxId) public isActive returns (uint256[] memory){
        require(kBox.ownerOf(_kBoxId) == msg.sender, "You are not the owner of this kBox");
        require(kBox.getApproved(_kBoxId) == address(this), "This contract is not approved to burn this kBox");

        kBox.burn(_kBoxId);

        // Mint a bundle of NFTs
        uint256[] memory tokenIds = _mintBundle(bundleSize);

        emit BundleMinted(msg.sender, tokenIds);
        return tokenIds;
    }

    /**
     * @notice Sets the DNA for each NFT in a minted bundle.
     * @dev Admin-only function that assigns a unique DNA to each NFT in the bundle, ensuring that each NFT has distinct characteristics. Validates that the lengths of the `tokenIds` and `dnas` arrays match and correspond to the current `bundleSize`.
     * @param tokenIds Array of token IDs for which to set DNA.
     * @param dnas Array of DNA values corresponding to each token ID.
     */
    function setBundleDna(uint256[] memory tokenIds, uint256[] memory dnas) public onlyAdmin {        
        require(tokenIds.length == dnas.length, "Array lengths do not match");
        require(tokenIds.length == bundleSize, "Array length must match bundle size");
        for (uint256 i = 0; i < bundleSize; i++) {
            kNFT.setDna(tokenIds[i], dnas[i]);
        }
    }

    /**
     * @notice Updates the address of the kBox NFT contract.
     * @dev Admin-only function to change the contract address through which the smart contract interacts with kBox NFTs. Emits a `KNFTChanged` event on success.
     * @param _kBox The new address of the kBox contract.
     */
    function setKBox(address _kBox) public onlyAdmin {
        require(_kBox != address(0), "kBox address is not set");
        kBox = IKondux(_kBox);
        emit KBoxChanged(_kBox);
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

    /// @notice Sets the Kondux NFT contract address.
    /// @dev Can only be called by an admin, requires non-zero address.
    /// @param _kNFT The new KNFT address.
    function setKNFT(address _kNFT) public onlyAdmin {
        require(_kNFT != address(0), "KNFT address is not set");
        kNFT = IKondux(_kNFT);
        emit KNFTChanged(_kNFT);
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
     * @notice Returns the address of the kBox NFT contract.
     * @return The current address interfaced by this contract for kBox NFT operations.
     */
    function getKBox() public view returns (address) {
        return address(kBox);
    }

    /**
     * @notice Returns the address of the treasury contract.
     * @return The current treasury contract address for financial transactions related to minting.
     */
    function getTreasury() public view returns (address) {
        return address(treasury);
    }

    // Internal functions are utilized by public functions to perform core operations in a secure and encapsulated manner.

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

    // Modifiers enhance function behaviors with pre-conditions, making the contract's logic more modular, readable, and secure.

    /**
     * @dev Ensures a function is only callable when the contract is not paused.
     */
    modifier isActive() {
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
}