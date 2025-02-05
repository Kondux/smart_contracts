// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Kondux_NFT.sol";
import "./interfaces/IAuthority.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title kNFTFactory
 * @dev Deploys new Kondux contracts, optionally charges ETH, and assigns default royalty fees
 *      to the Authority's vault. Allows open or restricted creation via a toggle, and
 *      maintains a whitelist for free or zero-royalty deployments.
 */
contract kNFTFactory is AccessControl {
    // ------------------ Roles ------------------ //

    /// @notice Role definition for factory administrators who can configure factory parameters.
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    // ------------------ State ------------------ //

    /// @notice Authority contract reference (manages vault address, etc.).
    IAuthority public authority;

    /// @notice If true, the factory can create new kNFT contracts. If false, creation is disabled.
    bool public isFactoryActive = true;

    /// @notice If true, the contract charges an ETH fee on creation unless the deployer is whitelisted.
    bool public isFeeEnabled = false;

    /// @notice Amount of ETH to charge if fees are enabled.
    uint256 public creationFee = 0.05 ether;

    /// @notice Default royalty fee numerator (e.g. 100 = 1%, if using a 10,000 denominator).
    uint96 public defaultRoyaltyFee = 100; // 1% by default

    /// @notice If true, only addresses with FACTORY_ADMIN_ROLE can call createKonduxEIP4906().
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

        // Grant deployer all necessary roles to configure factory.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);

        // Deployer is also whitelisted for free creation by default.
        freeCreators[msg.sender] = true;
    }

    // ------------------ Modifiers ------------------ //

    /**
     * @dev If `isRestricted` is true, only addresses with FACTORY_ADMIN_ROLE can call the function.
     *      If false, anyone can call.
     */
    modifier restrictedOrAnyone() {
        if (isRestricted) {
            require(hasRole(FACTORY_ADMIN_ROLE, msg.sender), "Not factory admin");
        }
        _;
    }

    // ------------------ Core Factory Logic ------------------ //

    /**
     * @notice Create a new Kondux contract (with EIP-4906 logic) under optional fee payment and default or zero royalty.
     * @dev The caller (msg.sender) ends up as the admin (DEFAULT_ADMIN_ROLE, MINTER_ROLE, DNA_MODIFIER_ROLE)
     *      in the newly deployed kNFT contract by transferring roles from the factory to the caller.
     * @param name   The ERC721 name for the new NFT collection.
     * @param symbol The ERC721 symbol for the new NFT collection.
     * @return The address of the newly deployed kNFT contract.
     */
    function createKonduxEIP4906(
        string memory name,
        string memory symbol
    )
        external
        payable
        restrictedOrAnyone
        returns (address)
    {
        require(isFactoryActive, "Factory is not active");

        // 1) Handle Fees (if enabled and caller is not free).
        if (isFeeEnabled && !freeCreators[msg.sender]) {
            require(msg.value >= creationFee, "Insufficient ETH for creation fee");

            // Forward all ETH directly to the Authority's vault.
            (bool success, ) = authority.vault().call{value: msg.value}("");
            require(success, "ETH transfer to vault failed");
        } else {
            // If no fee is expected, make sure no ETH is sent.
            require(msg.value == 0, "No fee required, do not send ETH");
        }

        // 2) Deploy a new Kondux NFT contract.
        //    The factory (address(this)) is the msg.sender in the constructor, so it initially has admin roles.
        Kondux newNFT = new Kondux(name, symbol);

        // 3) Transfer roles to the user (msg.sender):
        //    By default, newNFT's constructor grants all roles to the deployer (this factory).
        //    We now reassign those roles to msg.sender, then remove them from the factory.
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.MINTER_ROLE(), msg.sender, true);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), msg.sender, true);

        // Revoke from factory (address(this)).
        newNFT.setRole(newNFT.DEFAULT_ADMIN_ROLE(), address(this), false);
        newNFT.setRole(newNFT.MINTER_ROLE(), address(this), false);
        newNFT.setRole(newNFT.DNA_MODIFIER_ROLE(), address(this), false);

        // 4) Assign royalty:
        //    - If deployer is whitelisted, they get 0% royalty
        //    - Else, use the factory's defaultRoyaltyFee.
        uint96 royaltyToSet = freeCreators[msg.sender] ? 0 : defaultRoyaltyFee;
        newNFT.setDefaultRoyalty(authority.vault(), royaltyToSet);

        // 5) Emit event for external tracking.
        emit kNFTDeployed(address(newNFT), msg.sender);

        // 6) Return the address of the newly deployed contract.
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
     * @param _isRestricted If true, only factory admins can create new kNFTs. Otherwise anyone can.
     */
    function setRestricted(bool _isRestricted) external onlyRole(FACTORY_ADMIN_ROLE) {
        isRestricted = _isRestricted;
        emit FactoryToggled(isFactoryActive, isFeeEnabled, isRestricted);
    }

    /**
     * @notice Sets the default royalty fee used for new contracts (in basis points, e.g., 100 = 1%).
     * @param _fee The default royalty fee for newly deployed kNFTs.
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
     * @dev Revert any direct ETH sent to the factory outside of the createKonduxEIP4906() flow.
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
}
