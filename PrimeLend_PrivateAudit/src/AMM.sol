// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IERC20.sol";

/// @title ConstantProductAMM
/// @notice xy=k AMM. Contains intentional vulnerabilities.
contract AMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply; // LP shares
    mapping(address => uint256) public balanceOf;
    uint256 public feeBps = 30; // 0.3%

    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool zeroForOne);
    event AddLiquidity(address indexed user, uint256 a0, uint256 a1, uint256 shares);
    event RemoveLiquidity(address indexed user, uint256 a0, uint256 a1, uint256 shares);

    constructor(address t0, address t1) {
        token0 = IERC20(t0); token1 = IERC20(t1);
    }

    function addLiquidity(uint256 a0, uint256 a1) external returns (uint256 shares) {
        if (totalSupply == 0) {
            shares = sqrt(a0 * a1);
        } else {
            // BUG (M): uses arithmetic mean instead of min ratio -> LP inflation
            shares = (a0 * totalSupply) / reserve0;
        }
        require(shares > 0, "zero shares");
        require(token0.transferFrom(msg.sender, address(this), a0), "t0");
        require(token1.transferFrom(msg.sender, address(this), a1), "t1");
        reserve0 += a0; reserve1 += a1;
        totalSupply += shares;
        balanceOf[msg.sender] += shares;
        emit AddLiquidity(msg.sender, a0, a1, shares);
    }

    function removeLiquidity(uint256 shares) external returns (uint256 a0, uint256 a1) {
        require(shares <= balanceOf[msg.sender], "insufficient");
        a0 = (shares * reserve0) / totalSupply;
        a1 = (shares * reserve1) / totalSupply;
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        reserve0 -= a0; reserve1 -= a1;
        require(token0.transfer(msg.sender, a0), "t0");
        require(token1.transfer(msg.sender, a1), "t1");
        emit RemoveLiquidity(msg.sender, a0, a1, shares);
    }

    function swap(bool zeroForOne, uint256 amountIn, uint256 minOut) external returns (uint256 amountOut) {
        // BUG (H): no slippage protection enforced beyond minOut param (user must set; default 0 allowed)
        // BUG (H): reentrancy via token callback if token is ERC777
        if (zeroForOne) {
            uint256 amountInWithFee = amountIn * (10000 - feeBps);
            amountOut = (amountInWithFee * reserve1) / (reserve0 * 10000 + amountInWithFee);
            require(token0.transferFrom(msg.sender, address(this), amountIn), "in");
            require(token1.transfer(msg.sender, amountOut), "out");
            reserve0 += amountIn; reserve1 -= amountOut;
        } else {
            uint256 amountInWithFee = amountIn * (10000 - feeBps);
            amountOut = (amountInWithFee * reserve0) / (reserve1 * 10000 + amountInWithFee);
            require(token1.transferFrom(msg.sender, address(this), amountIn), "in");
            require(token0.transfer(msg.sender, amountOut), "out");
            reserve1 += amountIn; reserve0 -= amountOut;
        }
        require(amountOut >= minOut, "slippage");
        emit Swap(msg.sender, amountIn, amountOut, zeroForOne);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x; uint256 z = (x + 1) / 2;
        while (z < y) { y = z; z = (x / z + z) / 2; }
    }

    /// @notice VULNERABLE (H): flash swap without fee accrual / repayment check
    function flashSwap(uint256 amount0, uint256 amount1, address to, bytes calldata data) external {
        if (amount0 > 0) require(token0.transfer(to, amount0), "t0");
        if (amount1 > 0) require(token1.transfer(to, amount1), "t1");
        // callback
        (bool ok, ) = to.call(data);
        require(ok, "callback failed");
        // BUG: no repayment verification
        require(reserve0 <= token0.balanceOf(address(this)), "r0");
        require(reserve1 <= token1.balanceOf(address(this)), "r1");
    }
}