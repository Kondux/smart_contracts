// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Kondux_NFT.sol";
import "./interfaces/IAuthority.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title kNFTFactory
 * @notice Deploys new Kondux contracts (ERC721+EIP-4906+ERC2981),
 *         optionally charges ETH for creation, and sets an *informational* default royalty
 *         (compliant with ERC-2981) pointing to the Authority vault.
 *         Whether or not that royalty is actually paid depends on off-chain or marketplace logic.
 */
contract kNFTFactory is AccessControl {
    // ------------------ Roles ------------------ //

    /// @notice Role for factory administrators who can configure factory parameters.
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    // ------------------ State ------------------ //

    /// @notice Authority contract (manages vault address, etc.).
    IAuthority public authority;

    /// @notice If true, the factory can create new kNFT contracts. If false, creation is disabled.
    bool public isFactoryActive = true;

    /// @notice If true, the contract charges an ETH fee on creation unless the deployer is whitelisted.
    bool public isFeeEnabled = false;

    /// @notice Amount of ETH to charge if fees are enabled.
    uint256 public creationFee = 0.05 ether;

    /// @notice Default royalty fee numerator (e.g., 100 = 1% if using a 10,000 denominator).
    /// @dev This is purely informational for marketplaces. The contract does not enforce it on-chain.
    uint96 public defaultRoyaltyFee = 100; // 1% by default

    /// @notice If true, only addresses with FACTORY_ADMIN_ROLE can call createKondux().
    bool public isRestricted = false;

    /// @notice Whitelist for free (no ETH fee) deployments. Also used to set 0% royalty if desired.
    mapping(address => bool) public freeCreators;

    // ------------------ Events ------------------ //

    /// @dev Emitted when a new kNFT (Kondux) contract is deployed.
    event kNFTDeployed(address indexed newkNFT, address indexed admin);

    /// @dev Emitted when the factory toggles or configuration is changed.
    event FactoryToggled(bool isFactoryActive, bool isFeeEnabled, bool isRestricted);
    event FactoryFeeUpdated(uint256 newFee);
    event FactoryRoyaltyFeeUpdated(uint96 newFee);
    event FreeCreatorUpdated(address indexed creator, bool isFree);

    // ------------------ Constructor ------------------ //

    /**
     * @param _authority The address of the Authority contract (manages the vault, etc.).
     */
    constructor(address _authority) {
        require(_authority != address(0), "Authority cannot be zero address");
        authority = IAuthority(_authority);

        // Grant deployer roles to configure the factory.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);

        // Deployer is also whitelisted for free creation by default.
        freeCreators[msg.sender] = true;
    }

    // ------------------ Modifiers ------------------ //

    /**
     * @dev If `isRestricted` is true, only addresses with FACTORY_ADMIN_ROLE can call the function.
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
     * @notice Create a new Kondux contract (EIP-4906 + ERC2981).
     *         If `isFeeEnabled` is true and the caller is not whitelisted, they must pay the creationFee.
     *         The caller (msg.sender) ends up as the admin (DEFAULT_ADMIN_ROLE, MINTER_ROLE, DNA_MODIFIER_ROLE)
     *         in the newly deployed kNFT contract.
     *
     * @dev The default royalty set here is purely informational for ERC-2981. 
     *      Actual royalty payments depend on marketplace or off-chain logic.
     *
     * @param name   The ERC721 name for the new NFT collection.
     * @param symbol The ERC721 symbol for the new NFT collection.
     * @return The address of the newly deployed kNFT contract.
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

        // -- 1) Handle optional creation fee
        if (isFeeEnabled && !freeCreators[msg.sender]) {
            require(msg.value >= creationFee, "Insufficient ETH for creation fee");
            // Forward all ETH directly to the Authority's vault.
            (bool success, ) = authority.vault().call{value: msg.value}("");
            require(success, "ETH transfer to vault failed");
        } else {
            // If no fee is required, ensure none is sent.
            require(msg.value == 0, "No fee required, do not send ETH");
        }

        // -- 2) Deploy a new Kondux NFT contract
        //       This contract is the deployer, so it temporarily has admin roles.
        Kondux newNFT = new Kondux(name, symbol);

        // -- 3) Transfer roles from the factory (this address) to msg.sender
        //       The Kondux constructor granted all roles to address(this), so we reassign them:
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.MINTER_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), msg.sender, true);        

        // -- 4) Set the default royalty info (purely informational per ERC-2981)
        newNFT.setDefaultRoyalty(authority.vault(), defaultRoyaltyFee); // 1% by default

        // -- 5) Revoke roles from the factory (this address)
        newNFT.setRole(newNFT.MINTER_ROLE(), address(this), false);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), address(this), false);
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), address(this), false);

        // -- 6) Emit event
        emit kNFTDeployed(address(newNFT), msg.sender);

        // -- 7) Return contract address
        return address(newNFT);
    }

    // ------------------ Admin / Configuration ------------------ //

    /**
     * @notice Enable or disable the factory. If disabled, creation is blocked.
     * @param _isFactoryActive Toggle for factory activity.
     */
    function setFactoryActive(bool _isFactoryActive) external onlyRole(FACTORY_ADMIN_ROLE) {
        isFactoryActive = _isFactoryActive;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Enable or disable fee collection on creation.
     * @param _isFeeEnabled Toggle for fee requirement.
     */
    function setFeeEnabled(bool _isFeeEnabled) external onlyRole(FACTORY_ADMIN_ROLE) {
        isFeeEnabled = _isFeeEnabled;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Set the creation fee (in WEI) if `isFeeEnabled` is true.
     * @param _fee The new fee amount required for creation.
     */
    function setCreationFee(uint256 _fee) external onlyRole(FACTORY_ADMIN_ROLE) {
        creationFee = _fee;
        emit FactoryFeeUpdated(_fee);
    }

    /**
     * @notice Enable or disable the restriction to FACTORY_ADMIN_ROLE for new contract creation.
     * @param _isRestricted If true, only factory admins can create new kNFTs; otherwise anyone can.
     */
    function setRestricted(bool _isRestricted) external onlyRole(FACTORY_ADMIN_ROLE) {
        isRestricted = _isRestricted;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Sets the default royalty fee for new contracts (in basis points, e.g., 100 = 1%).
     * @param _fee The default royalty fee for newly deployed kNFTs.
     *
     * Note: This does not enforce on-chain royalties; it simply sets `royaltyInfo` for integrators.
     */
    function setDefaultRoyaltyFee(uint96 _fee) external onlyRole(FACTORY_ADMIN_ROLE) {
        defaultRoyaltyFee = _fee;
        emit FactoryRoyaltyFeeUpdated(_fee);
    }

    /**
     * @notice Update or add an address to the free creation whitelist. 
     *         Whitelisted addresses pay no creation fee and receive 0% royalty.
     * @param creator The address to be added or removed from freeCreators.
     * @param isFree  True to enable free creation, false to disable.
     */
    function setFreeCreator(address creator, bool isFree) external onlyRole(FACTORY_ADMIN_ROLE) {
        freeCreators[creator] = isFree;
        emit FreeCreatorUpdated(creator, isFree);
    }

    /**
     * @notice Updates the Authority contract address.
     * @param _authority The new Authority contract address.
     */
    function setAuthority(address _authority) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_authority != address(0), "Cannot be zero address");
        authority = IAuthority(_authority);
    }

    // ------------------ Emergency Withdraws ------------------ //

    /**
     * @notice Withdraw any ETH accidentally sent to this contract. Only callable by factory admins.
     * @param to Address to receive the withdrawn ETH.
     */
    function emergencyWithdrawETH(address to) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(to != address(0), "Cannot withdraw to zero address");
        uint256 balance = address(this).balance;
        (bool success, ) = to.call{value: balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Withdraw ERC20 tokens accidentally sent to this contract. Only callable by factory admins.
     * @param token  ERC20 token address.
     * @param to     Address to receive the tokens.
     * @param amount Number of tokens to withdraw.
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
     * @dev Revert any direct ETH sent to the factory outside of the createKondux() flow.
     */
    receive() external payable {
        revert("No direct ETH deposits");
    }

    /**
     * @dev Revert any fallback calls with ETH or data.
     */
    fallback() external payable {
        revert("Fallback not permitted");
    }

    // ------------------ Getters ------------------ //
    /** 
     * @notice Check if a given address is a factory admin.
     * @param _address The address to check.
     * @return True if the address has the FACTORY_ADMIN_ROLE.
     */
    
    function isFactoryAdmin(address _address) external view returns (bool) {
        return hasRole(FACTORY_ADMIN_ROLE, _address);
    }
}
