// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStakingV1 {
    function userDeposits(uint256)
        external
        view
        returns (
            address token,
            address staker,
            uint256 deposited,
            uint256 redeemed,
            uint256 timeOfLastUpdate,
            uint256 lastDepositTime,
            uint256 unclaimedRewards,
            uint256 timelock,
            uint8 timelockCategory,
            uint256 ratioERC20
        );

    function userDepositsIds(address, uint256) external view returns (uint256);

    function authorizedERC20(address) external view returns (bool);

    function minStakeERC20(address) external view returns (uint256);

    function compoundFreqERC20(address) external view returns (uint256);

    function aprERC20(address) external view returns (uint256);

    function withdrawalFeeERC20(address) external view returns (uint256);

    function foundersRewardBoostERC20(address) external view returns (uint256);

    function kNFTRewardBoostERC20(address) external view returns (uint256);

    function ratioERC20(address) external view returns (uint256);

    function decimalsERC20(address) external view returns (uint8);

    function totalWithdrawalFees(address) external view returns (uint256);

    function divisorERC20(address) external view returns (uint256);

    function earlyWithdrawalPenalty(address) external view returns (uint256);

    function totalStaked(address) external view returns (uint256);

    function totalRewarded(address) external view returns (uint256);

    function userTotalStakedByCoin(address, address) external view returns (uint256);

    function userTotalRewardedByCoin(address, address) external view returns (uint256);

    function timelockDurations(uint8) external view returns (uint256);

    function timelockCategoryBoost(uint256) external view returns (uint256);

    function allowedDnaVersions(uint256) external view returns (bool);

    function helixERC20() external view returns (address);

    function konduxERC721Founders() external view returns (address);

    function konduxERC721kNFT() external view returns (address);

    function treasury() external view returns (address);
}
