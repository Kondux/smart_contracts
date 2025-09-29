// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./Staking.sol";
import "./interfaces/IStakingV1.sol";

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

    /// @dev Thrown when attempting to import a deposit that does not exist on the legacy contract.
    error LegacyDepositMissing(uint256 depositId);

    /// @dev Thrown when attempting to import a deposit that is already present in this contract.
    error DepositAlreadyImported(uint256 depositId);

    event LegacyDepositImported(
        uint256 indexed depositId,
        address indexed staker,
        address indexed token,
        uint256 deposited,
        uint256 unclaimedRewards
    );

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
     * @notice Copies the configuration for a staking token from the legacy contract.
     * @dev Only callable by the governor.
     * @param legacy The address of the live staking V1 contract.
     * @param token The ERC20 token whose configuration should be copied.
     */
    function importLegacyTokenConfig(address legacy, address token) external onlyGovernor {
        require(token != address(0), "token zero address");

        IStakingV1 legacyContract = IStakingV1(legacy);

        minStakeERC20[token] = legacyContract.minStakeERC20(token);
        compoundFreqERC20[token] = legacyContract.compoundFreqERC20(token);
        aprERC20[token] = legacyContract.aprERC20(token);
        withdrawalFeeERC20[token] = legacyContract.withdrawalFeeERC20(token);
        foundersRewardBoostERC20[token] = legacyContract.foundersRewardBoostERC20(token);
        kNFTRewardBoostERC20[token] = legacyContract.kNFTRewardBoostERC20(token);
        ratioERC20[token] = legacyContract.ratioERC20(token);
        decimalsERC20[token] = legacyContract.decimalsERC20(token);
        divisorERC20[token] = legacyContract.divisorERC20(token);
        earlyWithdrawalPenalty[token] = legacyContract.earlyWithdrawalPenalty(token);

        totalWithdrawalFees[token] = legacyContract.totalWithdrawalFees(token);

        bool authorized = legacyContract.authorizedERC20(token);
        _setAuthorizedERC20(token, authorized);
    }

    /**
     * @notice Imports timelock durations and reward boosts from the legacy contract.
     * @dev Iterates the first four categories (0-3) which are actively used in V1.
     * @param legacy The address of the live staking V1 contract.
     */
    function importLegacyTimelockConfig(address legacy) external onlyGovernor {
        IStakingV1 legacyContract = IStakingV1(legacy);
        for (uint8 category = 0; category < 4; ++category) {
            timelockDurations[category] = legacyContract.timelockDurations(category);
            timelockCategoryBoost[category] = legacyContract.timelockCategoryBoost(category);
        }
    }

    /**
     * @notice Mirrors the DNA version permission flag from the legacy contract.
     * @param legacy The address of the live staking V1 contract.
     * @param version The DNA version identifier to synchronise.
     */
    function importLegacyDnaVersion(address legacy, uint256 version) external onlyGovernor {
        allowedDnaVersions[version] = IStakingV1(legacy).allowedDnaVersions(version);
    }

    /**
     * @notice Copies total withdrawal fee accounting for a token from the legacy contract.
     * @param legacy The address of the live staking V1 contract.
     * @param token The token whose accumulated withdrawal fees should be copied.
     */
    function importLegacyWithdrawalFees(address legacy, address token) external onlyGovernor {
        totalWithdrawalFees[token] = IStakingV1(legacy).totalWithdrawalFees(token);
    }

    /**
     * @notice Imports a batch of deposits from the legacy contract.
     * @param legacy The address of the live staking V1 contract.
     * @param depositIds The list of deposit identifiers to copy.
     */
    function importLegacyDeposits(address legacy, uint256[] calldata depositIds)
        external
        onlyGovernor
    {
        IStakingV1 legacyContract = IStakingV1(legacy);
        for (uint256 i = 0; i < depositIds.length; ++i) {
            _importLegacyDeposit(legacyContract, depositIds[i]);
        }
    }

    /**
     * @notice Imports a single deposit from the legacy contract.
     * @param legacy The address of the live staking V1 contract.
     * @param depositId The identifier of the deposit to copy.
     */
    function importLegacyDeposit(address legacy, uint256 depositId) external onlyGovernor {
        _importLegacyDeposit(IStakingV1(legacy), depositId);
    }

    function _importLegacyDeposit(IStakingV1 legacy, uint256 depositId) internal {
        (
            address token,
            address staker,
            uint256 deposited,
            uint256 redeemed,
            uint256 timeOfLastUpdate,
            uint256 lastDepositTime,
            uint256 unclaimedRewards,
            uint256 timelock,
            uint8 timelockCategory,
            uint256 ratioStored
        ) = legacy.userDeposits(depositId);

        if (staker == address(0)) {
            revert LegacyDepositMissing(depositId);
        }

        if (userDeposits[depositId].staker != address(0)) {
            revert DepositAlreadyImported(depositId);
        }

        userDeposits[depositId] = Staker({
            token: token,
            staker: staker,
            deposited: deposited,
            redeemed: redeemed,
            timeOfLastUpdate: timeOfLastUpdate,
            lastDepositTime: lastDepositTime,
            unclaimedRewards: unclaimedRewards,
            timelock: timelock,
            timelockCategory: timelockCategory,
            ratioERC20: ratioStored
        });

        userDepositsIds[staker].push(depositId);

        if (deposited > 0) {
            totalStaked[token] += deposited;
            userTotalStakedByCoin[token][staker] += deposited;
        }

        if (redeemed > 0) {
            totalRewarded[token] += redeemed;
            userTotalRewardedByCoin[token][staker] += redeemed;
        }

        _depositAprSnapshot[depositId] = legacy.aprERC20(token);
        _hasSnapshot[depositId] = true;

        uint256 nextId = _getNextDepositId();
        uint256 candidateNext = depositId + 1;
        if (candidateNext > nextId) {
            _setNextDepositId(candidateNext);
        }

        emit LegacyDepositImported(depositId, staker, token, deposited, unclaimedRewards);
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
