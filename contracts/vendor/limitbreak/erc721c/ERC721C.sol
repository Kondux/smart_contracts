// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/AutomaticValidatorTransferApproval.sol";
import "../utils/CreatorTokenBase.sol";
import "../token/erc721/ERC721OpenZeppelin.sol";
import "../interfaces/ITransferValidatorSetTokenType.sol";
import {TOKEN_TYPE_ERC721} from "../permit-c/Constants.sol";

/**
 * @title ERC721C
 * @author Limit Break, Inc.
 * @notice Extends OpenZeppelin's ERC721 implementation with Creator Token functionality, which
 *         allows the contract owner to update the transfer validation logic by managing a security policy in
 *         an external transfer validation security policy registry.  See {CreatorTokenTransferValidator}.
 */
abstract contract ERC721C is ERC721OpenZeppelin, CreatorTokenBase, AutomaticValidatorTransferApproval {
    /**
     * @notice Overrides behavior of isApprovedFor all such that if an operator is not explicitly approved
     *         for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner, operator);

        if (!isApproved) {
            if (autoApproveTransfersFromValidator) {
                isApproved = operator == address(getTransferValidator());
            }
        }
    }

    /**
     * @notice Indicates whether the contract implements the specified interface.
     * @dev Overrides supportsInterface in ERC165.
     * @param interfaceId The interface id
     * @return true if the contract implements the specified interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ICreatorToken).interfaceId ||
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /// @dev Applies transfer validation around the core ERC721 state update logic
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
    override(ERC721)
        returns (address previousOwner)
    {
        address from = _ownerOf(tokenId);
        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        if (isMint && !isBurn) {
            _validateBeforeTransfer(address(0), to, tokenId);
        } else if (!isMint && isBurn) {
            _validateBeforeTransfer(from, address(0), tokenId);
        } else {
            _validateBeforeTransfer(from, to, tokenId);
        }

        previousOwner = super._update(to, tokenId, auth);

        if (isMint && !isBurn) {
            _validateAfterTransfer(address(0), to, tokenId);
        } else if (!isMint && isBurn) {
            _validateAfterTransfer(previousOwner, address(0), tokenId);
        } else {
            _validateAfterTransfer(previousOwner, to, tokenId);
        }
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(TOKEN_TYPE_ERC721);
    }
}

/**
 * @title ERC721CInitializable
 * @author Limit Break, Inc.
 * @notice Initializable implementation of ERC721C to allow for EIP-1167 proxy clones.
 */
abstract contract ERC721CInitializable is ERC721OpenZeppelinInitializable, CreatorTokenBase, AutomaticValidatorTransferApproval {
    function initializeERC721(string memory name_, string memory symbol_) public override {
        super.initializeERC721(name_, symbol_);

        _emitDefaultTransferValidator();
        _registerTokenType(getTransferValidator());
    }

    /**
     * @notice Overrides behavior of isApprovedFor all such that if an operator is not explicitly approved
     *         for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner, operator);

        if (!isApproved) {
            if (autoApproveTransfersFromValidator) {
                isApproved = operator == address(getTransferValidator());
            }
        }
    }

    /**
     * @notice Indicates whether the contract implements the specified interface.
     * @dev Overrides supportsInterface in ERC165.
     * @param interfaceId The interface id
     * @return true if the contract implements the specified interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ICreatorToken).interfaceId ||
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /// @dev Applies transfer validation around the core ERC721 state update logic
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
    override(ERC721)
        returns (address previousOwner)
    {
        address from = _ownerOf(tokenId);
        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        if (isMint && !isBurn) {
            _validateBeforeTransfer(address(0), to, tokenId);
        } else if (!isMint && isBurn) {
            _validateBeforeTransfer(from, address(0), tokenId);
        } else {
            _validateBeforeTransfer(from, to, tokenId);
        }

        previousOwner = super._update(to, tokenId, auth);

        if (isMint && !isBurn) {
            _validateAfterTransfer(address(0), to, tokenId);
        } else if (!isMint && isBurn) {
            _validateAfterTransfer(previousOwner, address(0), tokenId);
        } else {
            _validateAfterTransfer(previousOwner, to, tokenId);
        }
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(TOKEN_TYPE_ERC721);
    }
}
