// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IKonduxNFT {
    function setBaseURI(string memory _newURI) external returns (string memory);
    function setTransferValidator(address validator) external;
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function baseURI() external view returns (string memory);
    function getTransferValidator() external view returns (address);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function MINTER_ROLE() external view returns (bytes32);
    function DNA_MODIFIER_ROLE() external view returns (bytes32);
}

/**
 * @title CopyNFTSettings
 * @notice Copies settings from old NFT to new NFT
 */
contract CopyNFTSettingsScript is Script {
    address constant NEW_NFT = 0xdC75300bAbaC28BA2A28393D3494DeEeE452E361;

    // Transfer validator from old contract
    address constant TRANSFER_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // Base URI from old contract (note: contains old contract address)
    // You may want to update this to use the new contract address
    string constant BASE_URI = "https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/0xdC75300bAbaC28BA2A28393D3494DeEeE452E361/";

    // Role members from old contract
    address constant MANUFACTURER = 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114;
    address constant EXTRA_MINTER = 0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF;

    function run() external {
        uint256 adminKey = vm.envUint("PROD_DEPLOYER_PK");
        address admin = vm.addr(adminKey);

        console2.log("=== Copying NFT Settings ===");
        console2.log("Admin:", admin);
        console2.log("New NFT:", NEW_NFT);
        console2.log("");

        IKonduxNFT nft = IKonduxNFT(NEW_NFT);

        bytes32 DEFAULT_ADMIN_ROLE = nft.DEFAULT_ADMIN_ROLE();
        bytes32 MINTER_ROLE = nft.MINTER_ROLE();
        bytes32 DNA_MODIFIER_ROLE = nft.DNA_MODIFIER_ROLE();

        vm.startBroadcast(adminKey);

        // 1. Set Base URI
        console2.log("Setting Base URI...");
        nft.setBaseURI(BASE_URI);
        console2.log("  Done:", BASE_URI);

        // 2. Set Transfer Validator
        console2.log("Setting Transfer Validator...");
        nft.setTransferValidator(TRANSFER_VALIDATOR);
        console2.log("  Done:", TRANSFER_VALIDATOR);

        // 3. Grant DEFAULT_ADMIN_ROLE to manufacturer
        if (!nft.hasRole(DEFAULT_ADMIN_ROLE, MANUFACTURER)) {
            console2.log("Granting DEFAULT_ADMIN_ROLE to manufacturer...");
            nft.grantRole(DEFAULT_ADMIN_ROLE, MANUFACTURER);
            console2.log("  Done:", MANUFACTURER);
        } else {
            console2.log("Manufacturer already has DEFAULT_ADMIN_ROLE");
        }

        // 4. Grant MINTER_ROLE to extra addresses
        if (!nft.hasRole(MINTER_ROLE, MANUFACTURER)) {
            console2.log("Granting MINTER_ROLE to manufacturer...");
            nft.grantRole(MINTER_ROLE, MANUFACTURER);
            console2.log("  Done:", MANUFACTURER);
        } else {
            console2.log("Manufacturer already has MINTER_ROLE");
        }

        if (!nft.hasRole(MINTER_ROLE, EXTRA_MINTER)) {
            console2.log("Granting MINTER_ROLE to extra minter...");
            nft.grantRole(MINTER_ROLE, EXTRA_MINTER);
            console2.log("  Done:", EXTRA_MINTER);
        } else {
            console2.log("Extra minter already has MINTER_ROLE");
        }

        // 5. Grant DNA_MODIFIER_ROLE to extra address
        if (!nft.hasRole(DNA_MODIFIER_ROLE, EXTRA_MINTER)) {
            console2.log("Granting DNA_MODIFIER_ROLE to extra address...");
            nft.grantRole(DNA_MODIFIER_ROLE, EXTRA_MINTER);
            console2.log("  Done:", EXTRA_MINTER);
        } else {
            console2.log("Extra address already has DNA_MODIFIER_ROLE");
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Settings Copied Successfully ===");
    }
}
