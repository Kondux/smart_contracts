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
    /// @dev Storage slot index of the next deposit identifier in {Staking}.
    bytes32 private constant _DEPOSIT_IDS_SLOT = bytes32(uint256(1));

    /// @dev Snapshot of the APR that applied when a deposit was created.
    mapping(uint256 => uint256) private _depositAprSnapshot;
    /// @dev Tracks whether a deposit has an APR snapshot recorded.
    mapping(uint256 => bool) private _hasSnapshot;

    /// @dev Thrown when attempting to restake rewards with a modified APR.
    error APRChangedForDeposit(uint256 depositId, uint256 originalApr, uint256 currentApr);

    /// @dev Thrown when attempting to import a deposit that is already present in this contract.
    error DepositAlreadyImported(uint256 depositId);

    event DepositImported(
        uint256 indexed depositId,
        address indexed staker,
        address indexed token,
        uint256 deposited,
        uint256 unclaimedRewards
    );

    struct DepositImport {
        uint256 depositId;
        address token;
        address staker;
        uint256 deposited;
        uint256 redeemed;
        uint256 timeOfLastUpdate;
        uint256 lastDepositTime;
        uint256 unclaimedRewards;
        uint256 timelock;
        uint8 timelockCategory;
        uint256 ratioStored;
        uint256 aprSnapshot;
    }

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

    /**
     * @notice Returns the identifier that will be assigned to the next deposit.
     */
    function getNextDepositId() external view returns (uint256) {
        return _getNextDepositId();
    }

    /**
     * @notice Imports pre-validated deposit data.
     * @dev Expects the caller (typically the governor) to supply canonical deposit records.
     * @param deposits The list of deposits to persist.
     * @param nextDepositId The next deposit identifier to program after imports complete.
     */
    function importDeposits(DepositImport[] calldata deposits, uint256 nextDepositId)
        external
        onlyGovernor
    {
        for (uint256 i = 0; i < deposits.length; ++i) {
            DepositImport calldata data = deposits[i];

            if (userDeposits[data.depositId].staker != address(0)) {
                revert DepositAlreadyImported(data.depositId);
            }

            userDeposits[data.depositId] = Staker({
                token: data.token,
                staker: data.staker,
                deposited: data.deposited,
                redeemed: data.redeemed,
                timeOfLastUpdate: data.timeOfLastUpdate,
                lastDepositTime: data.lastDepositTime,
                unclaimedRewards: data.unclaimedRewards,
                timelock: data.timelock,
                timelockCategory: data.timelockCategory,
                ratioERC20: data.ratioStored
            });

            userDepositsIds[data.staker].push(data.depositId);

            if (data.deposited > 0) {
                totalStaked[data.token] += data.deposited;
                userTotalStakedByCoin[data.token][data.staker] += data.deposited;
            }

            if (data.redeemed > 0) {
                totalRewarded[data.token] += data.redeemed;
                userTotalRewardedByCoin[data.token][data.staker] += data.redeemed;
            }

            _depositAprSnapshot[data.depositId] = data.aprSnapshot;
            _hasSnapshot[data.depositId] = true;

            emit DepositImported(
                data.depositId,
                data.staker,
                data.token,
                data.deposited,
                data.unclaimedRewards
            );
        }

        uint256 currentNext = _getNextDepositId();
        if (nextDepositId > currentNext) {
            _setNextDepositId(nextDepositId);
        }
    }

    function _getNextDepositId() internal view returns (uint256 nextId) {
        bytes32 slot = _DEPOSIT_IDS_SLOT;
        assembly {
            nextId := sload(slot)
        }
    }

    function _setNextDepositId(uint256 nextId) internal {
        bytes32 slot = _DEPOSIT_IDS_SLOT;
        assembly {
            sstore(slot, nextId)
        }
    }
}
