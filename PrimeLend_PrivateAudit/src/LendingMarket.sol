// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IERC20.sol";

interface IPriceFeed { function getPrice(address token) external view returns (uint256); }

/// @title LendingMarket — borrow against LP tokens
contract LendingMarket {
    IERC20 public immutable collateral; // LP token
    IERC20 public immutable borrowAsset; // USDC
    IPriceFeed public oracle;
    uint256 public constant LTV = 7000;
    uint256 public constant BPS = 10_000;

    struct Position { uint256 collateral; uint256 debt; }
    mapping(address => Position) public positions;
    uint256 public totalDeposits;
    uint256 public totalBorrows;

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);

    constructor(address c, address b, address o) {
        collateral = IERC20(c); borrowAsset = IERC20(b); oracle = IPriceFeed(o);
    }

    function deposit(uint256 amount) external {
        require(collateral.transferFrom(msg.sender, address(this), amount), "tf");
        positions[msg.sender].collateral += amount;
        totalDeposits += amount;
        emit Deposit(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        Position storage p = positions[msg.sender];
        uint256 price = oracle.getPrice(address(collateral));
        // BUG (M): no staleness check; LP price can be manipulated
        uint256 val = (p.collateral * price) / 1e18;
        uint256 maxB = (val * LTV) / BPS;
        require(p.debt + amount <= maxB, "insufficient");
        p.debt += amount;
        totalBorrows += amount;
        require(borrowAsset.transfer(msg.sender, amount), "transfer");
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        Position storage p = positions[msg.sender];
        require(borrowAsset.transferFrom(msg.sender, address(this), amount), "tf");
        if (amount > p.debt) amount = p.debt;
        p.debt -= amount;
        totalBorrows -= amount;
    }

    function withdraw(uint256 amount) external {
        Position storage p = positions[msg.sender];
        require(p.collateral >= amount, "insufficient");
        require(p.debt == 0, "debt");
        p.collateral -= amount;
        totalDeposits -= amount;
        require(collateral.transfer(msg.sender, amount), "transfer");
    }

    // BUG (H): anyone can set oracle
    function setOracle(address o) external { oracle = IPriceFeed(o); }
}