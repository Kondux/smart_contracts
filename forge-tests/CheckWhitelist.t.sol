// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";

interface ITransferValidator {
    function isAccountInList(uint48 id, uint8 listType, address account) external view returns (bool);
    function getListAccounts(uint48 id, uint8 listType) external view returns (address[] memory);
}

contract CheckWhitelistTest is Test {
    ITransferValidator validator = ITransferValidator(0x721C008fdff27BF06E7E123956E2Fe03B63342e3);
    uint8 constant LIST_TYPE_WHITELIST = 1;
    
    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://cloudflare-eth.com"));
        vm.createSelectFork(rpcUrl);
}


    function test_CheckWhitelistOperators() public view {
        console.log("=== Whitelist ID 16 Operator Check ===");
        console.log("");
        
        // OpenSea / Seaport addresses
        address seaport15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
        address seaport14 = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
        address seaport11 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;
        address osConduit = 0x1E0049783F008A0085193E00003D00cd54003c71;
        
        // Other marketplaces
        address blur = 0x39da41747a83aeE658334415666f3EF92DD0D541;
        address blurV2 = 0xB2ecfE4E4d61F8790BBB9De2d166c15958B6eB97;
        address looksrare = 0x59728544B08AB483533076417FbBB2fD0B17CE3a;
        address looksrareV2 = 0x0000000000E655fAe4d56241588680F86E3b2377;
        address x2y2 = 0x74312363e45DCaBA76c59ec49a7Aa8A65a67EeD3;
        address sudoswap = 0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329;
        
        console.log("--- OpenSea / Seaport ---");
        console.log("Seaport 1.5:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, seaport15));
        console.log("Seaport 1.4:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, seaport14));
        console.log("Seaport 1.1:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, seaport11));
        console.log("OpenSea Conduit:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, osConduit));
        
        console.log("");
        console.log("--- Other Marketplaces ---");
        console.log("Blur V1:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, blur));
        console.log("Blur V2:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, blurV2));
        console.log("LooksRare V1:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, looksrare));
        console.log("LooksRare V2:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, looksrareV2));
        console.log("X2Y2:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, x2y2));
        console.log("Sudoswap:", validator.isAccountInList(16, LIST_TYPE_WHITELIST, sudoswap));
    }
}
