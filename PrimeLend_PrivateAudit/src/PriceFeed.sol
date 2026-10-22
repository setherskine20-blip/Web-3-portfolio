// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PriceFeed (admin-controlled, no access control)
contract PriceFeed {
    mapping(address => uint256) public prices;
    address public owner;

    constructor() { owner = msg.sender; }

    // BUG (H): no onlyOwner modifier
    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getPrice(address token) external view returns (uint256) {
        require(prices[token] > 0, "no price");
        return prices[token];
    }

    // BUG (M): ownership transfer without two-step
    function transferOwnership(address newOwner) external {
        owner = newOwner;
    }
}