 // SPDX-License-Identifier: MIT
// Sources flattened with hardhat v2.11.2 https://hardhat.org

// File contracts/interfaces/INFTContract.sol

pragma solidity ^0.8.9;

interface INFTContract {
    // --------------- ERC1155 -----------------------------------------------------

    /// @notice Get the balance of an account's tokens.
    /// @param _owner  The address of the token holder
    /// @param _id     ID of the token
    /// @return        The _owner's balance of the token type requested
    function balanceOf(address _owner, uint256 _id)
        external
        view
        returns (uint256);

    /// @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
    /// @dev MUST emit the ApprovalForAll event on success.
    /// @param _operator  Address to add to the set of authorized operators
    /// @param _approved  True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
    /// @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
    /// MUST revert if `_to` is the zero address.
    /// MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
    /// MUST revert on any other error.
    /// MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
    /// After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
    /// @param _from    Source address
    /// @param _to      Target address
    /// @param _id      ID of the token type
    /// @param _value   Transfer amount
    /// @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external;

    /// @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
    /// @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
    /// MUST revert if `_to` is the zero address.
    /// MUST revert if length of `_ids` is not the same as length of `_values`.
    /// MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
    /// MUST revert on any other error.        
    /// MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
    /// Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
    /// After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
    /// @param _from    Source address
    /// @param _to      Target address
    /// @param _ids     IDs of each token type (order and length must match _values array)
    /// @param _values  Transfer amounts per token type (order and length must match _ids array)
    /// @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    // ---------------------- ERC721 ------------------------------------------------

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param tokenId The identifier for an NFT
    /// @return owner  The address of the owner of the NFT
    function ownerOf(uint256 tokenId) external view returns (address owner);

    // function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata data
    ) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;
}


// File contracts/NFTCommon.sol

pragma solidity ^0.8.9;
// helps with sending the NFTs, will be particularly useful for batch operations
library NFTCommon {
    /**
     @notice Transfers the NFT tokenID from to.
     @dev safuTransferFrom name to avoid collision with the interface signature definitions. The reason it is implemented the way it is,
      is because some NFT contracts implement both the 721 and 1155 standard at the same time. Sometimes, 721 or 1155 function does not work.
      So instead of relying on the user's input, or asking the contract what interface it implements, it is best to just make a good assumption
      about what NFT type it is (here we guess it is 721 first), and if that fails, we use the 1155 function to tranfer the NFT.
     @param nft     NFT address
     @param from    Source address
     @param to      Target address
     @param tokenID ID of the token type
     @param data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom_(
        INFTContract nft,
        address from,
        address to,
        uint256 tokenID,
        bytes memory data
    ) internal returns (bool) {
        // most are 721s, so we assume that that is what the NFT type is
        try nft.safeTransferFrom(from, to, tokenID, data) {
            return true;
            // on fail, use 1155s format
        } catch (bytes memory) {
            try nft.safeTransferFrom(from, to, tokenID, 1, data) {
                return true;
            } catch (bytes memory) {
                return false;
            }
        }
    }

    /**
     @notice Determines if potentialOwner is in fact an owner of at least 1 qty of NFT token ID.
     @param nft NFT address
     @param potentialOwner suspected owner of the NFT token ID
     @param tokenID id of the token
     @return quantity of held token, possibly zero
    */
    function quantityOf(
        INFTContract nft,
        address potentialOwner,
        uint256 tokenID
    ) internal view returns (uint256) {
        try nft.ownerOf(tokenID) returns (address owner) {
            if (owner == potentialOwner) {
                return 1;
            } else {
                return 0;
            }
        } catch (bytes memory) {
            try nft.balanceOf(potentialOwner, tokenID) returns (
                uint256 amount
            ) {
                return amount;
            } catch (bytes memory) {
                return 0;
            }
        }
    }
}
