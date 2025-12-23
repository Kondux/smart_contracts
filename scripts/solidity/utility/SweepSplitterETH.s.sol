// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IKonduxRoyaltySplitter {
    function sweepETH(uint256 tokenId) external;
    function pendingETH(address) external view returns (uint256);
    function manufacturerWallet() external view returns (address);
    function partnerWallet() external view returns (address);
    function defaultCreatorWallet() external view returns (address);
}

/**
 * @title SweepSplitterETH
 * @notice Sweeps accumulated ETH in the splitter and distributes to recipients
 */
contract SweepSplitterETHScript is Script {
    address constant SPLITTER = 0x61190B06C040Ce8829E0a688d2fE5b5ee599272A;

    function run() external {
        uint256 adminKey = vm.envUint("PROD_DEPLOYER_PK");
        address admin = vm.addr(adminKey);

        console2.log("=== Sweep Splitter ETH ===");
        console2.log("Admin:", admin);
        console2.log("Splitter:", SPLITTER);
        console2.log("");

        IKonduxRoyaltySplitter splitter = IKonduxRoyaltySplitter(SPLITTER);

        // Check current balance
        uint256 balance = address(SPLITTER).balance;
        console2.log("Splitter ETH balance:", balance, "wei");
        console2.log("                     ", balance / 1e15, "finney");
        console2.log("");

        if (balance == 0) {
            console2.log("No ETH to sweep");
            return;
        }

        // Get recipient addresses
        address manufacturer = splitter.manufacturerWallet();
        address partner = splitter.partnerWallet();
        address defaultCreator = splitter.defaultCreatorWallet();

        console2.log("Manufacturer:", manufacturer);
        console2.log("Partner:", partner);
        console2.log("Default Creator:", defaultCreator);
        console2.log("");

        // Token ID 10 was the one sold
        uint256 tokenId = 10;
        console2.log("Sweeping for token ID:", tokenId);

        vm.startBroadcast(adminKey);

        // Sweep the ETH - this distributes to pending balances
        splitter.sweepETH(tokenId);

        vm.stopBroadcast();

        console2.log("");
        console2.log("Swept! Pending balances updated.");
        console2.log("Recipients should call withdrawETH() to claim their share.");
        console2.log("");

        // Check pending balances after sweep
        console2.log("Pending ETH after sweep:");
        console2.log("  Manufacturer:", splitter.pendingETH(manufacturer));
        console2.log("  Partner:", splitter.pendingETH(partner));
        console2.log("  Creator:", splitter.pendingETH(defaultCreator));
    }
}
