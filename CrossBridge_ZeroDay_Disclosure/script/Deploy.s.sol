// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/CrossBridge.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address token = vm.envAddress("TOKEN_ADDRESS");
        address validator = vm.envAddress("VALIDATOR_ADDRESS");
        vm.startBroadcast(pk);
        CrossBridge b = new CrossBridge(token, validator);
        vm.stopBroadcast();
        console.log("Bridge:", address(b));
    }
}