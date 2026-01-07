// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKonduxRoyaltySplitter
 * @notice Interface for the Kondux royalty splitter contract
 */
interface IKonduxRoyaltySplitter {
    /*//////////////////////////////////////////////////////////////
                            ROLE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the ADMIN_ROLE identifier
    function ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns the DISTRIBUTOR_ROLE identifier
    function DISTRIBUTOR_ROLE() external view returns (bytes32);

    /// @notice Returns the COLLECTION_ROLE identifier
    function COLLECTION_ROLE() external view returns (bytes32);

    /// @notice Returns the FEE_ADMIN_ROLE identifier
    function FEE_ADMIN_ROLE() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                         ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Grant a role to an account
    function grantRole(bytes32 role, address account) external;

    /// @notice Revoke a role from an account
    function revokeRole(bytes32 role, address account) external;

    /// @notice Check if an account has a role
    function hasRole(bytes32 role, address account) external view returns (bool);
    /**
     * @notice Called by the NFT contract during a transfer to atomically distribute royalties
     * @param tokenId The token being transferred
     * @param from The seller
     * @param salePrice The sale price
     */
    function onTransferWithValue(
        uint256 tokenId,
        address from,
        uint256 salePrice
    ) external payable;

    /**
     * @notice Register a pending sale for atomic distribution
     * @param tokenId The token about to be sold
     * @return saleId A unique identifier for this sale
     */
    function registerSale(uint256 tokenId) external returns (bytes32 saleId);

    /**
     * @notice Receive payment for a specific sale and distribute immediately
     * @param saleId The unique sale identifier from registerSale()
     */
    function receivePaymentForSale(bytes32 saleId) external payable;

    /**
     * @notice Receive payment with tokenId directly specified
     * @param tokenId The token that was sold
     */
    function receivePaymentForToken(uint256 tokenId) external payable;

    /**
     * @notice Register creator info for a token
     * @param tokenId The token ID
     * @param creator The creator's address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function registerCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external;

    /**
     * @notice Batch register creators
     */
    function registerCreatorsBatch(
        uint256[] calldata tokenIds,
        address[] calldata creators,
        uint96[] calldata creatorCutsBP
    ) external;

    /**
     * @notice Get the split breakdown for a token
     */
    function getSplit(uint256 tokenId, uint256 amount) 
        external 
        view 
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator,
            uint96 creatorCutBP
        );

    /**
     * @notice Get creator info for a token
     */
    function getCreatorInfo(uint256 tokenId)
        external
        view
        returns (address creator, uint96 cutBP);

    /**
     * @notice Check if a token has creator info registered
     */
    function hasCreatorInfo(uint256 tokenId) external view returns (bool);

    /**
     * @notice Get pending ETH for an address
     */
    function getPendingETH(address recipient) external view returns (uint256);

    /**
     * @notice Withdraw accumulated ETH
     */
    function withdrawETH() external;

    /**
     * @notice Withdraw accumulated ERC20 tokens
     */
    function withdrawERC20(address token) external;

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enable or disable push (immediate) distribution mode
     */
    function setPushMode(bool enabled) external;

    /**
     * @notice Update wallet addresses
     */
    function setWallets(address manufacturerWallet, address partnerWallet) external;

    /**
     * @notice Update cut percentages
     */
    function setCuts(
        uint96 manufacturerCutBP,
        uint96 partnerCutBP,
        uint96 defaultCreatorCutBP
    ) external;

    /**
     * @notice Allows a registered creator to change their own receiving wallet
     * @param tokenId The token ID for which they are the creator
     * @param newWallet The new wallet address to receive royalties
     */
    function updateCreatorWallet(uint256 tokenId, address newWallet) external;

    /**
     * @notice Admin/Distributor can override creator registration
     * @param tokenId The token ID
     * @param creator The new creator address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function overrideCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external;

    /**
     * @notice Set the collection address (can only be called once if initially zero)
     * @dev Used by factory to set collection after deployment in splitter-first pattern
     * @param _collection The NFT collection address
     */
    function setCollection(address _collection) external;
}
