// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Kondux_NFT.sol"; 
import "./interfaces/IAuthority.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title kNFTFactory
 * @notice Deploys new Kondux contracts (ERC721 + EIP-4906 + On-Chain Royalty Enforcement),
 *         optionally charges ETH for creation, and sets an *informational* default royalty
 *         (compliant with ERC-2981) pointing to the Authority vault.
 */
contract kNFTFactory is AccessControl {
    // ------------------ Roles ------------------ //

    /// @notice Role for factory administrators who can configure factory parameters.
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    // ------------------ State ------------------ //

    /// @notice Authority contract (manages vault address, etc.).
    IAuthority public authority;

    /// @notice If true, the factory can create new kNFT (Kondux) contracts. If false, creation is disabled.
    bool public isFactoryActive = true;

    /// @notice If true, the contract charges an ETH fee on creation unless the deployer is whitelisted.
    bool public isFeeEnabled = false;

    /// @notice Amount of ETH to charge if fees are enabled.
    uint256 public creationFee = 0.05 ether;

    /// @notice Default royalty fee numerator (e.g., 100 = 1% if using a 10,000 denominator).
    /// @dev This is purely informational for ERC-2981. The new Kondux enforces on-chain royalties separately.
    uint96 public defaultRoyaltyFee = 100; // 1% by default

    /// @notice If true, only addresses with FACTORY_ADMIN_ROLE can call `createKondux()`.
    bool public isRestricted = false;

    /// @notice Whitelist for free (no ETH fee) deployments.
    mapping(address => bool) public freeCreators;

    // ------------------ Addresses for the New Kondux Constructor ------------------ //
    /// @dev Uniswap V2 router for price lookups
    address public uniswapV2Router; 
    /// @dev WETH address (for USDT->WETH->KNDX path)
    address public WETH;
    /// @dev KNDX token address
    address public KNDX;
    /// @dev Founder’s Pass contract
    IERC721 public foundersPass;

    // ------------------ Events ------------------ //

    event kNFTDeployed(address indexed newkNFT, address indexed admin);
    event FactoryToggled(bool isFactoryActive, bool isFeeEnabled, bool isRestricted);
    event FactoryFeeUpdated(uint256 newFee);
    event FactoryRoyaltyFeeUpdated(uint96 newFee);
    event FreeCreatorUpdated(address indexed creator, bool isFree);

    // ------------------ Constructor ------------------ //

    /**
     * @param _authority        The address of the Authority contract (manages the vault, etc.).
     */
    constructor(address _authority) {
        require(_authority != address(0), "Authority cannot be zero address");
        authority = IAuthority(_authority);

        // Grant deployer roles to configure the factory
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);

        // Deployer is also whitelisted for free creation
        freeCreators[msg.sender] = true;
    }

    // ------------------ Modifiers ------------------ //

    /**
     * @dev If `isRestricted` is true, only addresses with FACTORY_ADMIN_ROLE can call.
     *      Otherwise, anyone can call.
     */
    modifier restrictedOrAnyone() {
        if (isRestricted) {
            require(hasRole(FACTORY_ADMIN_ROLE, msg.sender), "Not factory admin");
        }
        _;
    }

    // ------------------ Core Factory Logic ------------------ //

    
    /**
     * @notice Creates a new Kondux NFT contract.
     *
     * @dev Deploys a new Kondux NFT contract, initializes it with the provided name and symbol along with stored addresses,
     * assigns necessary roles to the creator (msg.sender) and revokes the factory's roles.
     * Depending on the fee settings, it either requires a minimum creation fee or ensures no ETH is sent.
     * The sent fee (if applicable) is forwarded to the Authority's vault.
     *
     * Requirements:
     * - The factory must be active (isFactoryActive must be true).
     * - If fee is enabled and the caller is not exempt, at least 'creationFee' ETH must be sent.
     * - If fee is not required, no ETH should be sent.
     *
     * Emits a {kNFTDeployed} event indicating the deployment of the new NFT contract.
     *
     * @param name The name for the new NFT contract.
     * @param symbol The symbol for the new NFT contract.
     *
     * @return The address of the deployed Kondux NFT contract.
     */
    function createKondux(
        string memory name,
        string memory symbol
    )
        external
        payable
        restrictedOrAnyone
        returns (address)
    {
        require(isFactoryActive, "Factory is not active");

        // (1) Optional creation fee
        if (isFeeEnabled && !freeCreators[msg.sender]) {
            require(msg.value >= creationFee, "Insufficient ETH for creation fee");
            // Forward ETH to the Authority's vault
            (bool success, ) = authority.vault().call{value: msg.value}("");
            require(success, "ETH transfer to vault failed");
        } else {
            // If no fee is required, ensure none is sent
            require(msg.value == 0, "No fee required, do not send ETH");
        }

        // (2) Deploy a new Kondux NFT contract with the stored addresses
        //     The `_treasury` is `authority.vault()`.
        Kondux newNFT = new Kondux(
            name,
            symbol,
            uniswapV2Router,       // Uniswap router
            WETH,                  // WETH address
            KNDX,                  // KNDX token
            address(foundersPass), // Founder’s Pass contract
            authority.vault()      // treasury for 1% cut
        );

        // (3) Transfer roles from the factory to msg.sender
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.MINTER_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), msg.sender, true);

        // (4) Revoke roles from this factory
        newNFT.setRole(newNFT.MINTER_ROLE(), address(this), false);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), address(this), false);
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), address(this), false);

        // (5) Emit event
        emit kNFTDeployed(address(newNFT), msg.sender);

        // (6) Return address of new NFT contract
        return address(newNFT);
    }

    // ------------------ Admin / Configuration ------------------ //

    /**
     * @notice Sets the factory's active status.
     * @dev This function can only be called by an account with the FACTORY_ADMIN_ROLE.
     * @param _isFactoryActive A boolean that activates (true) or deactivates (false) the factory.
     *
     * Emits a {FactoryToggled} event indicating the new state of factory activity,
     * fee enabling, and restriction status.
     */
    function setFactoryActive(bool _isFactoryActive) external onlyRole(FACTORY_ADMIN_ROLE) {
        isFactoryActive = _isFactoryActive;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Enables or disables fee functionality.
     * @dev Only callable by accounts with the FACTORY_ADMIN_ROLE.
     * @param _isFeeEnabled A boolean flag that determines whether fees are enabled (true) or disabled (false).
     *
     * Emits a FactoryToggled event with the following parameters:
     * - isFactoryActive: The current activation status of the factory.
     * - isFeeEnabled: The updated fee status as provided by _isFeeEnabled.
     * - isRestricted: The current restriction status.
     */
    function setFeeEnabled(bool _isFeeEnabled) external onlyRole(FACTORY_ADMIN_ROLE) {
        isFeeEnabled = _isFeeEnabled;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Updates the creation fee.
     * @dev Can only be called by addresses with the FACTORY_ADMIN_ROLE.
     *      Executes by setting the creation fee to the provided value and emitting a FactoryFeeUpdated event.
     * @param _fee The new creation fee amount.
     */
    function setCreationFee(uint256 _fee) external onlyRole(FACTORY_ADMIN_ROLE) {
        creationFee = _fee;
        emit FactoryFeeUpdated(_fee);
    }

    /**
     * @notice Toggles the restricted status of the factory.
     * @dev Only callable by an account with the FACTORY_ADMIN_ROLE.
     *      Updates the state variable 'isRestricted' and emits the FactoryToggled event.
     * @param _isRestricted Boolean value indicating the new restricted status.
     */
    function setRestricted(bool _isRestricted) external onlyRole(FACTORY_ADMIN_ROLE) {
        isRestricted = _isRestricted;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Set the default royalty fee for newly deployed Kondux (for ERC2981).
     * @param _fee Basis points, e.g., 100 => 1% if denominator = 10,000.
     */
    function setDefaultRoyaltyFee(uint96 _fee) external onlyRole(FACTORY_ADMIN_ROLE) {
        defaultRoyaltyFee = _fee;
        emit FactoryRoyaltyFeeUpdated(_fee);
    }

    /**
     * @notice Update or add an address to the free-creation whitelist.
     */
    function setFreeCreator(address creator, bool isFree) external onlyRole(FACTORY_ADMIN_ROLE) {
        freeCreators[creator] = isFree;
        emit FreeCreatorUpdated(creator, isFree);
    }

    /**
     * @notice Update the Authority contract address.
     */
    function setAuthority(address _authority) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_authority != address(0), "Cannot be zero address");
        authority = IAuthority(_authority);
    }

    /**
     * @notice Set the Uniswap V2 router address for price lookups.
     * @param _router The new Uniswap V2 router address.
     */
    function setUniswapV2Router(address _router) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_router != address(0), "Invalid router address");
        uniswapV2Router = _router;
    }

    /**
     * @notice Set the WETH address.
     * @param _weth The new WETH address.
     */
    function setWETH(address _weth) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_weth != address(0), "Invalid WETH address");
        WETH = _weth;
    }

    /**
     * @notice Set the KNDX token address.
     * @param _kndx The new KNDX token address.
     */
    function setKNDX(address _kndx) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_kndx != address(0), "Invalid KNDX address");
        KNDX = _kndx;
    }

    /**
     * @notice Set the Founder’s pass contract address.
     * @param _foundersPass The new Founder’s pass contract.
     */
    function setFoundersPass(IERC721 _foundersPass) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(address(_foundersPass) != address(0), "Invalid FoundersPass address");
        foundersPass = _foundersPass;
    }

    // ------------------ Emergency Withdraws ------------------ //

    /**
     * @notice Withdraw tokens in emergency by transferring the specified amount to a given address.
     * @dev Only callable by accounts with the FACTORY_ADMIN_ROLE. Requires a non-zero destination address and a successful token transfer.
     * @param token The ERC20 token to be withdrawn.
     * @param to The address to which the tokens will be sent.
     * @param amount The number of tokens to withdraw.
     */
    function emergencyWithdrawToken(IERC20 token, address to, uint256 amount)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
    {
        require(to != address(0), "Cannot withdraw to zero address");
        require(token.transfer(to, amount), "Token transfer failed");
    }

    // ------------------ Prevent Direct ETH Transfers ------------------ //

    /**
     * @notice Prevents the contract from receiving Ether directly.
     * @dev The receive function reverts all direct ETH transfers, ensuring that no deposits are accepted.
     */
    receive() external payable {
        revert("No direct ETH deposits");
    }

    /**
     * @notice Reverts any call made to the contract using a fallback mechanism.
     * @dev This fallback function is set to receive ether but always reverts with a message.
     * It ensures that any call that does not match an existing function signature is not processed,
     * preventing unintended interactions.
     */
    fallback() external payable {
        revert("Fallback not permitted");
    }

    // ------------------ Getters ------------------ //

    
    /**
     * @notice Checks if the provided address is a factory administrator.
     * @dev This function verifies that the address has the FACTORY_ADMIN_ROLE.
     * @param _address The address to be checked.
     * @return bool Returns true if the address holds the FACTORY_ADMIN_ROLE, false otherwise.
     */
    function isFactoryAdmin(address _address) external view returns (bool) {
        return hasRole(FACTORY_ADMIN_ROLE, _address);
    }
}
