// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./utils/ForgeTestBase.sol";
import {StakingV2} from "contracts/StakingV2.sol";
import {Authority} from "contracts/Authority.sol";
import {Treasury} from "contracts/Treasury.sol";
import {KNDX} from "contracts/KNDX_ERC20.sol";
import {Helix} from "contracts/Helix.sol";
import {KonduxERC721Founders} from "contracts/tests/KonduxERC721Founders.sol";
import {KonduxERC721kNFT} from "contracts/tests/KonduxERC721kNFT.sol";
import {IStakingV1} from "contracts/interfaces/IStakingV1.sol";

contract StakingV2MigrationForkTest is ForgeTestBase {
    address private constant LEGACY_STAKING = 0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC;

    IStakingV1 private constant legacy = IStakingV1(LEGACY_STAKING);

    StakingV2 internal staking;
    Authority internal authority;
    Treasury internal treasury;
    KNDX internal konduxStub;
    Helix internal helixStub;
    KonduxERC721Founders internal foundersStub;
    KonduxERC721kNFT internal knftStub;

    struct LegacyDepositData {
        address token;
        address staker;
        uint256 deposited;
        uint256 redeemed;
        uint256 timeOfLastUpdate;
        uint256 lastDepositTime;
        uint256 unclaimedRewards;
        uint256 timelock;
        uint8 timelockCategory;
        uint256 ratioERC20;
    }

    uint256 internal constant MAX_IMPORTS = 50;

    mapping(address => bool) internal tokenProcessed;
    mapping(address => uint256) internal expectedTotalStaked;
    mapping(address => uint256) internal expectedTotalRewarded;
    mapping(address => mapping(address => uint256)) internal expectedUserTotalStaked;
    mapping(address => mapping(address => uint256)) internal expectedUserTotalRewarded;
    mapping(address => uint256[]) internal importedDepositIdsByUser;
    address[] internal importedTokens;

    function setUp() public {
        string memory rpcUrl = string.concat(
            "https://eth-mainnet.g.alchemy.com/v2/",
            vm.envString("ALCHEMY_API_KEY")
        );
        uint256 fork = vm.createFork(rpcUrl);
        vm.selectFork(fork);

        authority = new Authority(address(this), address(this), address(this), address(this));
        treasury = new Treasury(address(authority));
        authority.pushVault(address(treasury), true);

        konduxStub = new KNDX();
        konduxStub.enableTrading();
        konduxStub.faucet();

        helixStub = new Helix("Helix", "HLX");
        foundersStub = new KonduxERC721Founders();
        knftStub = new KonduxERC721kNFT();

        staking = new StakingV2(
            address(authority),
            address(konduxStub),
            address(treasury),
            address(foundersStub),
            address(knftStub),
            address(helixStub)
        );

        staking.setHelixERC20(legacy.helixERC20());
        staking.setKonduxERC721Founders(legacy.konduxERC721Founders());
        staking.setKonduxERC721kNFT(legacy.konduxERC721kNFT());
    staking.setTreasury(legacy.treasury());

    staking.importLegacyTimelockConfig(LEGACY_STAKING);
    staking.importLegacyDnaVersion(LEGACY_STAKING, 1);
    }

    function test_importsAllLegacyDepositsAndKeepsAccountingInSync() public {
        uint256 legacyNextId = legacyNextDepositId();
        require(legacyNextId > 0, "legacy has no deposits");

        uint256 imported;
        uint256 sampleDepositId;
        LegacyDepositData memory sampleDeposit;
        bool sampleCaptured;
        uint256 highestImportedId;

        for (uint256 depositId = 0; depositId < legacyNextId; ++depositId) {
            LegacyDepositData memory legacyDeposit = readLegacyDeposit(depositId);
            if (legacyDeposit.staker == address(0)) {
                continue;
            }

            if (!tokenProcessed[legacyDeposit.token]) {
                staking.importLegacyTokenConfig(LEGACY_STAKING, legacyDeposit.token);
                staking.importLegacyWithdrawalFees(LEGACY_STAKING, legacyDeposit.token);
                tokenProcessed[legacyDeposit.token] = true;
                importedTokens.push(legacyDeposit.token);
            }

            if (!sampleCaptured) {
                sampleDepositId = depositId;
                sampleDeposit = legacyDeposit;
                sampleCaptured = true;
            }

            staking.importLegacyDeposit(LEGACY_STAKING, depositId);

            imported++;
            importedDepositIdsByUser[legacyDeposit.staker].push(depositId);

            expectedTotalStaked[legacyDeposit.token] += legacyDeposit.deposited;
            expectedTotalRewarded[legacyDeposit.token] += legacyDeposit.redeemed;
            expectedUserTotalStaked[legacyDeposit.token][legacyDeposit.staker] += legacyDeposit.deposited;
            expectedUserTotalRewarded[legacyDeposit.token][legacyDeposit.staker] += legacyDeposit.redeemed;

            if (depositId > highestImportedId) {
                highestImportedId = depositId;
            }

            if (imported == MAX_IMPORTS) {
                break;
            }
        }

        require(imported > 0, "no deposits imported");

        uint256 nextIdAfterImport = staking.getNextDepositId();
        assertEq(nextIdAfterImport, highestImportedId + 1, "next deposit id mismatch");

        // Validate sample deposit state matches exactly.
        {
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
                uint256 ratioERC20
            ) = staking.userDeposits(sampleDepositId);

            assertEq(token, sampleDeposit.token, "token mismatch");
            assertEq(staker, sampleDeposit.staker, "staker mismatch");
            assertEq(deposited, sampleDeposit.deposited, "deposited mismatch");
            assertEq(redeemed, sampleDeposit.redeemed, "redeemed mismatch");
            assertEq(timeOfLastUpdate, sampleDeposit.timeOfLastUpdate, "update time mismatch");
            assertEq(lastDepositTime, sampleDeposit.lastDepositTime, "last deposit time mismatch");
            assertEq(unclaimedRewards, sampleDeposit.unclaimedRewards, "unclaimed mismatch");
            assertEq(timelock, sampleDeposit.timelock, "timelock mismatch");
            assertEq(timelockCategory, sampleDeposit.timelockCategory, "category mismatch");
            assertEq(ratioERC20, sampleDeposit.ratioERC20, "ratio mismatch");
        }

        for (uint256 i = 0; i < importedTokens.length; ++i) {
            address token = importedTokens[i];
            assertEq(
                staking.totalStaked(token),
                expectedTotalStaked[token],
                "total staked mismatch"
            );
            assertEq(
                staking.totalRewarded(token),
                expectedTotalRewarded[token],
                "total rewarded mismatch"
            );
            assertEq(
                staking.totalWithdrawalFees(token),
                legacy.totalWithdrawalFees(token),
                "withdrawal fee mismatch"
            );
        }

        assertEq(
            staking.userTotalStakedByCoin(sampleDeposit.token, sampleDeposit.staker),
            expectedUserTotalStaked[sampleDeposit.token][sampleDeposit.staker],
            "user total staked mismatch"
        );

        assertEq(
            staking.userTotalRewardedByCoin(sampleDeposit.token, sampleDeposit.staker),
            expectedUserTotalRewarded[sampleDeposit.token][sampleDeposit.staker],
            "user reward total mismatch"
        );

        uint256 expectedLength = importedDepositIdsByUser[sampleDeposit.staker].length;
        uint256 newLength = userDepositsIdsLength(address(staking), sampleDeposit.staker);
        assertEq(newLength, expectedLength, "deposit id list length mismatch");

        for (uint256 i = 0; i < expectedLength; ++i) {
            uint256 newDepositIdAtIndex = userDepositsIdAt(address(staking), sampleDeposit.staker, i);
            uint256 expectedDepositId = importedDepositIdsByUser[sampleDeposit.staker][i];
            assertEq(newDepositIdAtIndex, expectedDepositId, "deposit id list mismatch");
        }
    }

    function readLegacyDeposit(uint256 depositId) internal view returns (LegacyDepositData memory data) {
        (
            data.token,
            data.staker,
            data.deposited,
            data.redeemed,
            data.timeOfLastUpdate,
            data.lastDepositTime,
            data.unclaimedRewards,
            data.timelock,
            data.timelockCategory,
            data.ratioERC20
        ) = legacy.userDeposits(depositId);
    }

    function legacyNextDepositId() internal returns (uint256) {
        return uint256(vm.load(LEGACY_STAKING, bytes32(uint256(1))));
    }

    function userDepositsIdsLength(address stakingAddress, address user)
        internal
        returns (uint256)
    {
        bytes32 slot = keccak256(abi.encode(user, uint256(2)));
        return uint256(vm.load(stakingAddress, slot));
    }

    function userDepositsIdAt(address stakingAddress, address user, uint256 index)
        internal
        returns (uint256)
    {
        bytes32 slot = keccak256(abi.encode(user, uint256(2)));
        bytes32 base = keccak256(abi.encode(slot));
        return uint256(vm.load(stakingAddress, bytes32(uint256(base) + index)));
    }
}
