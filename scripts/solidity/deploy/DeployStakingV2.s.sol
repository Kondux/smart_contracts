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

        vm.stopBroadcast();

        _logSummary(addresses, stakingAddress, result.newlyDeployed);
    }

    function _resolveAddresses(address deployer) internal returns (DeploymentResult memory result) {
        if (block.chainid == 1) {
            AddressBook memory addresses;
            addresses.label = "Ethereum Mainnet";
            addresses.authority = vm.parseAddress("0x6A005c11217863c4e300Ce009c5Ddc7e1672150A");
            addresses.konduxToken = vm.parseAddress("0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1");
            addresses.treasury = vm.parseAddress("0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E");
            addresses.foundersPass = vm.parseAddress("0x0fD5576c2842bD62dd00C5256491D11CcAD84306");
            addresses.knft = vm.parseAddress("0xeA6aB2871d5B3bbe6Ded740C812D85700Bae33c0");
            addresses.helix = vm.parseAddress("0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4");
            addresses.deployDependencies = false;
            result.addresses = addresses;
            result.newlyDeployed = new HelperDeployment[](0);
            return result;
        }

        if (block.chainid == 11155111) {
            AddressBook memory addresses;
            addresses.label = "Ethereum Sepolia";
            addresses.authority = vm.parseAddress("0x685a13093Ca561f531c93185B942a3F33385E14e");
            addresses.konduxToken = vm.parseAddress("0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc");
            addresses.treasury = vm.parseAddress("0xD5A6Af8F9C20CAF7872611D6773152AA50180F83");
            addresses.foundersPass = vm.parseAddress("0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499");
            addresses.knft = vm.parseAddress("0x5C7eD88DBbD99F513235A1911d41A5C57E2FFB78");
            addresses.helix = vm.parseAddress("0xb94F89750D9889656a6d081A0f06CBD3fA3Ad04b");
            addresses.deployDependencies = false;
            result.addresses = addresses;
            result.newlyDeployed = new HelperDeployment[](0);
            return result;
        }

        return _deployLocalDependencies(deployer);
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

        address currentStaking = treasury.stakingContract();
        if (currentStaking != stakingAddress) {
            treasury.setStakingContract(stakingAddress);
            console2.log("Treasury: staking contract updated", stakingAddress);
        } else {
            console2.log("Treasury: staking contract already configured");
        }

        treasury.erc20ApprovalSetup(konduxToken, type(uint256).max);
        console2.log("Treasury: unlimited allowance granted to StakingV2");
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
        string memory envName = (block.chainid == 1 || block.chainid == 31337) ? "PROD_DEPLOYER_PK" : "DEPLOYER_PK";
        uint256 key = vm.envUint(envName);
        require(key != 0, "DeployStakingV2: private key env var missing");
        return key;
    }
}
