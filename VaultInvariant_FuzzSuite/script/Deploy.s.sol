// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Vault.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address asset = vm.envAddress("ASSET_ADDRESS");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        vm.startBroadcast(pk);
        YieldMaxVault v = new YieldMaxVault(asset, feeRecipient, msg.sender);
        vm.stopBroadcast();
        console.log("Vault:", address(v));
    }
}