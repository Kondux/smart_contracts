// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./Staking.sol";

/**
 * @title StakingV2
 * @notice Extends the original Staking contract by snapshotting the APR for every
 *         new deposit. This allows governors to update the APR at any time without
 *         impacting positions that are still timelocked. Additionally, if the
 *         current APR differs from the deposit's original APR snapshot, the user
 *         must open a new staking position instead of restaking rewards.
 */
contract StakingV2 is Staking {
    /// @dev Snapshot of the APR that applied when a deposit was created.
    mapping(uint256 => uint256) private _depositAprSnapshot;
    /// @dev Tracks whether a deposit has an APR snapshot recorded.
    mapping(uint256 => bool) private _hasSnapshot;

    /// @dev Thrown when attempting to restake rewards with a modified APR.
    error APRChangedForDeposit(uint256 depositId, uint256 originalApr, uint256 currentApr);

    constructor(
        address _authority,
        address _konduxERC20,
        address _treasury,
        address _konduxERC721Founders,
        address _konduxERC721kNFT,
        address _helixERC20
    )
        Staking(
            _authority,
            _konduxERC20,
            _treasury,
            _konduxERC721Founders,
            _konduxERC721kNFT,
            _helixERC20
        )
    {}

    /// @inheritdoc Staking
    function _afterDeposit(uint256 depositId, address token) internal override {
        _depositAprSnapshot[depositId] = aprERC20[token];
        _hasSnapshot[depositId] = true;
    }

    /// @inheritdoc Staking
    function _beforeStakeRewards(uint256 depositId) internal view override {
        if (!_hasSnapshot[depositId]) {
            return;
        }

        Staker storage deposit = userDeposits[depositId];
        uint256 currentApr = aprERC20[deposit.token];
        uint256 originalApr = _depositAprSnapshot[depositId];

        if (currentApr != originalApr) {
            revert APRChangedForDeposit(depositId, originalApr, currentApr);
        }
    }

    /// @inheritdoc Staking
    function _getAPRForDeposit(address token, uint256 depositId)
        internal
        view
        override
        returns (uint256)
    {
        if (_hasSnapshot[depositId]) {
            return _depositAprSnapshot[depositId];
        }

        return super._getAPRForDeposit(token, depositId);
    }

    /**
     * @notice Returns the APR snapshot stored for a deposit.
     * @param depositId The identifier of the deposit.
     * @return snapshot The stored APR value.
     * @return exists True if the deposit has an APR snapshot recorded.
     */
    function getDepositAprSnapshot(uint256 depositId)
        external
        view
        returns (uint256 snapshot, bool exists)
    {
        return (_depositAprSnapshot[depositId], _hasSnapshot[depositId]);
    }
}
