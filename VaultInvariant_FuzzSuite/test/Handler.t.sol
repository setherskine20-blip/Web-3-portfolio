// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract MockAsset {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender]-=a; balanceOf[to]+=a; return true; }
    function transferFrom(address f,address t,uint256 a) external returns (bool) { allowance[f][msg.sender]-=a; balanceOf[f]-=a; balanceOf[t]+=a; return true; }
    function approve(address s,uint256 a) external returns (bool) { allowance[msg.sender][s]=a; return true; }
}

contract MockStrategy {
    MockAsset public asset;
    uint256 public total;
    constructor(MockAsset a) { asset = a; }
    function deposit(uint256 a) external { asset.transferFrom(msg.sender, address(this), a); total += a; }
    function withdraw(uint256 a) external returns (uint256) { if (a > total) a = total; asset.transfer(msg.sender, a); total -= a; return a; }
    function totalAssets() external view returns (uint256) { return total; }
}

contract Handler is Test {
    YieldMaxVault public vault;
    MockAsset public asset;
    MockStrategy public strategy;

    address[] public actors;
    uint256 public ghostDeposits;
    uint256 public ghostWithdrawals;
    uint256 public ghostRedeems;
    uint256 public callCount;

    constructor(YieldMaxVault v, MockAsset a, MockStrategy s) {
        vault = v; asset = a; strategy = s;
        for (uint256 i = 0; i < 6; i++) {
            address ac = address(uint160(0x2000 + i));
            actors.push(ac);
            asset.mint(ac, 500_000e18);
            vm.prank(ac); asset.approve(address(vault), type(uint256).max);
        }
        // seed vault with strategy
        vm.prank(vault.owner()); vault.setStrategy(address(strategy));
    }

    function _actor(uint256 seed) internal view returns (address) { return actors[seed % actors.length]; }

    function deposit(uint256 as_, uint256 amt) external {
        address a = _actor(as_);
        amt = bound(amt, 1, 50_000e18);
        if (asset.balanceOf(a) < amt) return;
        vm.prank(a);
        try vault.deposit(amt, a) { ghostDeposits += amt; } catch {}
        callCount++;
    }

    function withdraw(uint256 as_, uint256 amt) external {
        address a = _actor(as_);
        uint256 sh = vault.balanceOf(a);
        if (sh == 0) return;
        uint256 assets = vault.convertToAssets(sh);
        amt = bound(amt, 1, assets);
        vm.prank(a);
        try vault.withdraw(amt, a, a) { ghostWithdrawals += amt; } catch {}
        callCount++;
    }

    function redeem(uint256 as_, uint256 sh) external {
        address a = _actor(as_);
        uint256 bal = vault.balanceOf(a);
        if (bal == 0) return;
        sh = bound(sh, 1, bal);
        vm.prank(a);
        try vault.redeem(sh, a, a) { ghostRedeems++; } catch {}
        callCount++;
    }

    function harvest() external {
        vm.prank(vault.owner());
        try vault.harvest() {} catch {}
        callCount++;
    }

    function warp(uint256 s) external {
        s = bound(s, 1, 3 days);
        vm.warp(block.timestamp + s);
        callCount++;
    }

    function pauseUnpause(uint256 flag) external {
        if (flag % 2 == 0) { vm.prank(vault.owner()); try vault.pause() {} catch {} }
        else { vm.prank(vault.owner()); try vault.unpause() {} catch {} }
        callCount++;
    }

    function actorCount() external view returns (uint256) { return actors.length; }
    function actorAt(uint256 i) external view returns (address) { return actors[i]; }
}