// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {StakingV2} from "contracts/StakingV2.sol";
import {Authority} from "contracts/Authority.sol";
import {Treasury} from "contracts/Treasury.sol";
import {KNDX} from "contracts/KNDX_ERC20.sol";
import {Helix} from "contracts/Helix.sol";
import {KonduxERC721Founders} from "contracts/tests/KonduxERC721Founders.sol";
import {KonduxERC721kNFT} from "contracts/tests/KonduxERC721kNFT.sol";

contract DeployStakingV2Script is Script {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");

    struct AddressBook {
        string label;
        address authority;
        address konduxToken;
        address treasury;
        address foundersPass;
        address knft;
        address helix;
        bool deployDependencies;
    }

    struct HelperDeployment {
        string name;
        address addr;
    }

    struct DeploymentResult {
        AddressBook addresses;
        HelperDeployment[] newlyDeployed;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== StakingV2 Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        vm.startBroadcast(deployerKey);

        DeploymentResult memory result = _resolveAddresses(deployer);
        AddressBook memory addresses = result.addresses;

        _logDependencies(addresses, result.newlyDeployed);

        StakingV2 staking = new StakingV2(
            addresses.authority,
            addresses.konduxToken,
            addresses.treasury,
            addresses.foundersPass,
            addresses.knft,
            addresses.helix
        );
        address stakingAddress = address(staking);
        console2.log("StakingV2 deployed:", stakingAddress);

        _configureHelix(addresses.helix, stakingAddress);
        _configureTreasury(addresses.treasury, addresses.konduxToken, stakingAddress);

        // WARNING: V2 now has MINTER_ROLE and BURNER_ROLE on Helix.
        // If V1 is still active, both contracts can mint/burn Helix simultaneously.
        // Do NOT authorize tokens on V2 (setAuthorizedERC20) until V1 is shut down,
        // or users could deposit into V2 prematurely before deposits are imported.
        console2.log("");
        console2.log("IMPORTANT: V2 has Helix roles but NO authorized tokens yet.");
        console2.log("Do NOT authorize tokens on V2 until V1 deposits are imported and V1 is shut down.");

        vm.stopBroadcast();

        _logSummary(addresses, stakingAddress, result.newlyDeployed);
    }

    function _resolveAddresses(address deployer) internal returns (DeploymentResult memory result) {
        if (block.chainid == 1) {
            AddressBook memory addresses;
            addresses.label = "Ethereum Mainnet";
            addresses.authority = _resolveEnvAddress("AUTHORITY_ADDRESS", vm.parseAddress("0x6A005c11217863c4e300Ce009c5Ddc7e1672150A"));
            addresses.konduxToken = _resolveEnvAddress("KONDUX_TOKEN_ADDRESS", vm.parseAddress("0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1"));
            addresses.treasury = _resolveEnvAddress("TREASURY_ADDRESS", vm.parseAddress("0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E"));
            addresses.foundersPass = _resolveEnvAddress("FOUNDERS_ADDRESS", vm.parseAddress("0x0fD5576c2842bD62dd00C5256491D11CcAD84306"));
            addresses.knft = _resolveEnvAddress("KNFT_ADDRESS", vm.parseAddress("0xeA6aB2871d5B3bbe6Ded740C812D85700Bae33c0"));
            addresses.helix = _resolveEnvAddress("HELIX_ADDRESS", vm.parseAddress("0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4"));
            addresses.deployDependencies = false;
            result.addresses = addresses;
            result.newlyDeployed = new HelperDeployment[](0);
            return result;
        }

        if (block.chainid == 11155111) {
            AddressBook memory addresses;
            addresses.label = "Ethereum Sepolia";
            addresses.authority = _resolveEnvAddress("AUTHORITY_ADDRESS", vm.parseAddress("0x685a13093Ca561f531c93185B942a3F33385E14e"));
            addresses.konduxToken = _resolveEnvAddress("KONDUX_TOKEN_ADDRESS", vm.parseAddress("0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc"));
            addresses.treasury = _resolveEnvAddress("TREASURY_ADDRESS", vm.parseAddress("0xD5A6Af8F9C20CAF7872611D6773152AA50180F83"));
            addresses.foundersPass = _resolveEnvAddress("FOUNDERS_ADDRESS", vm.parseAddress("0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499"));
            addresses.knft = _resolveEnvAddress("KNFT_ADDRESS", vm.parseAddress("0x5C7eD88DBbD99F513235A1911d41A5C57E2FFB78"));
            addresses.helix = _resolveEnvAddress("HELIX_ADDRESS", vm.parseAddress("0xb94F89750D9889656a6d081A0f06CBD3fA3Ad04b"));
            addresses.deployDependencies = false;
            result.addresses = addresses;
            result.newlyDeployed = new HelperDeployment[](0);
            return result;
        }

        if (block.chainid == 31337) {
            // Local Anvil: check if we're on a fork (mainnet contracts exist)
            // or a fresh Anvil (need to deploy everything).
            // Use DEPLOY_DEPENDENCIES=true env var to force fresh deploy.
            bool forceDeploy = vm.envOr("DEPLOY_DEPENDENCIES", false);
            address mainnetAuthority = vm.parseAddress("0x6A005c11217863c4e300Ce009c5Ddc7e1672150A");

            if (!forceDeploy && mainnetAuthority.code.length > 0) {
                // Fork detected: mainnet contracts exist at known addresses
                console2.log("Local Anvil: forked mainnet detected, using mainnet addresses");
                AddressBook memory addresses;
                addresses.label = "Local Anvil (forked mainnet)";
                addresses.authority = _resolveEnvAddress("AUTHORITY_ADDRESS", mainnetAuthority);
                addresses.konduxToken = _resolveEnvAddress("KONDUX_TOKEN_ADDRESS", vm.parseAddress("0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1"));
                addresses.treasury = _resolveEnvAddress("TREASURY_ADDRESS", vm.parseAddress("0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E"));
                addresses.foundersPass = _resolveEnvAddress("FOUNDERS_ADDRESS", vm.parseAddress("0x0fD5576c2842bD62dd00C5256491D11CcAD84306"));
                addresses.knft = _resolveEnvAddress("KNFT_ADDRESS", vm.parseAddress("0xeA6aB2871d5B3bbe6Ded740C812D85700Bae33c0"));
                addresses.helix = _resolveEnvAddress("HELIX_ADDRESS", vm.parseAddress("0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4"));
                addresses.deployDependencies = false;
                result.addresses = addresses;
                result.newlyDeployed = new HelperDeployment[](0);
                return result;
            }

            // No fork or forced deploy: deploy fresh dependencies
            console2.log("Local Anvil: deploying fresh dependencies");
            return _deployLocalDependencies(deployer);
        }

        revert(
            string.concat(
                "DeployStakingV2: Unsupported chain ID ",
                vm.toString(block.chainid),
                ". Supported: 1 (mainnet), 11155111 (sepolia), 31337 (local)"
            )
        );
    }

    function _resolveEnvAddress(string memory envKey, address fallback_) internal returns (address) {
        try vm.envAddress(envKey) returns (address addr) {
            if (addr != address(0)) {
                console2.log(string.concat("  [env] ", envKey, " ="), addr);
                return addr;
            }
        } catch {}
        return fallback_;
    }

    function _deployLocalDependencies(address deployer) internal returns (DeploymentResult memory result) {
        HelperDeployment[] memory deployments = new HelperDeployment[](6);
        uint256 count;

        Authority authority = new Authority(deployer, deployer, deployer, deployer);
        deployments[count++] = HelperDeployment({name: "Authority", addr: address(authority)});

        Treasury treasury = new Treasury(address(authority));
        deployments[count++] = HelperDeployment({name: "Treasury", addr: address(treasury)});

        KNDX kondux = new KNDX();
        deployments[count++] = HelperDeployment({name: "KNDX", addr: address(kondux)});
        kondux.enableTrading();

        Helix helix = new Helix("Helix", "HLX");
        deployments[count++] = HelperDeployment({name: "Helix", addr: address(helix)});

        KonduxERC721Founders founders = new KonduxERC721Founders();
        deployments[count++] = HelperDeployment({name: "KonduxERC721Founders", addr: address(founders)});

        KonduxERC721kNFT knft = new KonduxERC721kNFT();
        deployments[count++] = HelperDeployment({name: "KonduxERC721kNFT", addr: address(knft)});

        authority.pushVault(address(treasury), true);

        AddressBook memory addresses;
        addresses.label = string.concat("Local sandbox (chain ", vm.toString(block.chainid), ")");
        addresses.authority = address(authority);
        addresses.konduxToken = address(kondux);
        addresses.treasury = address(treasury);
        addresses.foundersPass = address(founders);
        addresses.knft = address(knft);
        addresses.helix = address(helix);
        addresses.deployDependencies = true;

        HelperDeployment[] memory trimmed = new HelperDeployment[](count);
        for (uint256 i = 0; i < count; ++i) {
            trimmed[i] = deployments[i];
        }

        result.addresses = addresses;
        result.newlyDeployed = trimmed;
    }

    function _configureHelix(address helixAddress, address stakingAddress) internal {
        if (helixAddress == address(0)) {
            console2.log("Helix address not provided; skipping configuration");
            return;
        }

        Helix helix = Helix(helixAddress);

        if (!helix.allowedContracts(stakingAddress)) {
            helix.setAllowedContract(stakingAddress, true);
            console2.log("Helix: whitelisted staking contract", stakingAddress);
        } else {
            console2.log("Helix: staking contract already whitelisted");
        }

        if (!helix.hasRole(MINTER_ROLE, stakingAddress)) {
            helix.setRole(MINTER_ROLE, stakingAddress, true);
            console2.log("Helix: MINTER_ROLE granted");
        } else {
            console2.log("Helix: MINTER_ROLE already granted");
        }

        if (!helix.hasRole(BURNER_ROLE, stakingAddress)) {
            helix.setRole(BURNER_ROLE, stakingAddress, true);
            console2.log("Helix: BURNER_ROLE granted");
        } else {
            console2.log("Helix: BURNER_ROLE already granted");
        }
    }

    function _configureTreasury(address treasuryAddress, address konduxToken, address stakingAddress) internal {
        if (treasuryAddress == address(0)) {
            console2.log("Treasury address not provided; skipping configuration");
            return;
        }
        if (konduxToken == address(0)) {
            console2.log("Kondux token address not provided; skipping treasury configuration");
            return;
        }

        Treasury treasury = Treasury(payable(treasuryAddress));

        if (!treasury.permissions(Treasury.STATUS.RESERVETOKEN, konduxToken)) {
            treasury.setPermission(Treasury.STATUS.RESERVETOKEN, konduxToken, true);
            console2.log("Treasury: Kondux token registered as reserve");
        } else {
            console2.log("Treasury: Kondux token already marked as reserve");
        }

        if (!treasury.permissions(Treasury.STATUS.RESERVEDEPOSITOR, stakingAddress)) {
            treasury.setPermission(Treasury.STATUS.RESERVEDEPOSITOR, stakingAddress, true);
            console2.log("Treasury: StakingV2 registered as depositor");
        } else {
            console2.log("Treasury: StakingV2 already depositor");
        }

        if (!treasury.permissions(Treasury.STATUS.RESERVESPENDER, stakingAddress)) {
            treasury.setPermission(Treasury.STATUS.RESERVESPENDER, stakingAddress, true);
            console2.log("Treasury: StakingV2 registered as spender");
        } else {
            console2.log("Treasury: StakingV2 already spender");
        }

        // NOTE: treasury.setStakingContract(V2) and treasury.erc20ApprovalSetup()
        // are DEFERRED to the shutdown script (ShutdownStakingV1.s.sol Phase 2).
        // Calling setStakingContract here would overwrite V1's treasury reference
        // while V1 is still active, and erc20ApprovalSetup uses the stored
        // stakingContract address. Both must happen atomically during V1 shutdown.
        address currentStaking = treasury.stakingContract();
        console2.log("Treasury: current stakingContract =", currentStaking);
        console2.log("Treasury: DEFERRED setStakingContract + erc20ApprovalSetup to shutdown script");
    }

    function _logDependencies(AddressBook memory addresses, HelperDeployment[] memory newlyDeployed) internal view {
        console2.log("Using dependency addresses:");
        console2.log("  Authority", addresses.authority);
        console2.log("  KonduxToken", addresses.konduxToken);
        console2.log("  Treasury", addresses.treasury);
        console2.log("  FoundersPass", addresses.foundersPass);
        console2.log("  kNFT", addresses.knft);
        console2.log("  Helix", addresses.helix);

        if (newlyDeployed.length > 0) {
            console2.log("Provisioned local helpers:");
            for (uint256 i = 0; i < newlyDeployed.length; ++i) {
                console2.log(string.concat("  ", newlyDeployed[i].name), newlyDeployed[i].addr);
            }
        }
    }

    function _logSummary(AddressBook memory addresses, address stakingAddress, HelperDeployment[] memory newlyDeployed)
        internal
        view
    {
        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", bytes(addresses.label).length != 0 ? addresses.label : _defaultNetworkLabel());
        console2.log("StakingV2:", stakingAddress);
        console2.log("Authority:", addresses.authority);
        console2.log("KonduxToken:", addresses.konduxToken);
        console2.log("Treasury:", addresses.treasury);
        console2.log("FoundersPass:", addresses.foundersPass);
        console2.log("kNFT:", addresses.knft);
        console2.log("Helix:", addresses.helix);

        if (newlyDeployed.length > 0) {
            console2.log("Helpers deployed during run:");
            for (uint256 i = 0; i < newlyDeployed.length; ++i) {
                console2.log(string.concat("  ", newlyDeployed[i].name), newlyDeployed[i].addr);
            }
        }
    }

    function _defaultNetworkLabel() internal view returns (string memory) {
        if (block.chainid == 1) return "Ethereum Mainnet";
        if (block.chainid == 11155111) return "Ethereum Sepolia";
        return string.concat("Chain ", vm.toString(block.chainid));
    }

    function _selectPrivateKey() internal view returns (uint256) {
        // Mainnet: require PROD_DEPLOYER_PK
        if (block.chainid == 1) {
            uint256 prodKey = vm.envUint("PROD_DEPLOYER_PK");
            require(prodKey != 0, "DeployStakingV2: PROD_DEPLOYER_PK not set");
            return prodKey;
        }
        // Local Anvil: try PROD_DEPLOYER_PK, fallback to Anvil default #0
        if (block.chainid == 31337) {
            string memory pk = vm.envOr("PROD_DEPLOYER_PK", string(""));
            if (bytes(pk).length > 0) {
                return vm.envUint("PROD_DEPLOYER_PK");
            }
            return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        // Sepolia / others: DEPLOYER_PK
        uint256 deployKey = vm.envUint("DEPLOYER_PK");
        require(deployKey != 0, "DeployStakingV2: DEPLOYER_PK not set");
        return deployKey;
    }
}
