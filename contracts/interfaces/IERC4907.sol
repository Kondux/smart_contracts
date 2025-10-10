// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.9;

interface IERC4907 {

    /// @notice Emitted when the `user` of an NFT or the `expires` of the `user` is changed

    event UpdateUser(uint256 indexed tokenId, address indexed user, uint64 expires);



    /// @notice Set the user and expires of an NFT

    /// @dev The zero address indicates there is no user

    /// @param tokenId The NFT to set the user/expires for

    /// @param user The new user of the NFT

    /// @param expires UNIX timestamp; the new user can use the NFT before this time

    function setUser(uint256 tokenId, address user, uint64 expires) external;



    /// @notice Get the user address of an NFT

    /// @dev The zero address indicates that there is no user or the user is expired

    /// @param tokenId The NFT to get the user address for

    /// @return The user address for this NFT

    function userOf(uint256 tokenId) external view returns(address);



    /// @notice Get the user expiration time of an NFT

    /// @dev The zero value indicates that there is no user

    /// @param tokenId The NFT to get the user expires for

    /// @return The user expiration timestamp

    function userExpires(uint256 tokenId) external view returns(uint256);

}