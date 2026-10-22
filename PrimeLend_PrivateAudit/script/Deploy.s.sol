// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AMM.sol";
import "../src/PriceFeed.sol";
import "../src/LendingMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address t0 = vm.envAddress("TOKEN0");
        address t1 = vm.envAddress("TOKEN1");
        address usdc = vm.envAddress("USDC");
        vm.startBroadcast(pk);
        AMM amm = new AMM(t0, t1);
        PriceFeed pf = new PriceFeed();
        LendingMarket lm = new LendingMarket(address(amm), usdc, address(pf));
        vm.stopBroadcast();
        console.log("AMM:", address(amm));
        console.log("PriceFeed:", address(pf));
        console.log("LendingMarket:", address(lm));
    }
}