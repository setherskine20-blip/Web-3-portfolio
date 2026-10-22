// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ChainlinkStyleOracle
/// @notice Price feed wrapper with staleness checks. Intentionally missing deviation guard.
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256 startedAt,
        uint256 updatedAt, uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

contract PriceOracle {
    AggregatorV3Interface public immutable feed;
    uint256 public constant STALENESS_THRESHOLD = 3600; // 1 hour

    constructor(address _feed) {
        feed = AggregatorV3Interface(_feed);
    }

    /// @notice Returns price scaled to 1e18.
    /// @dev VULNERABLE: no deviation bound vs. previous round; single feed, no TWAP fallback.
    function getPrice() external view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        require(answer > 0, "invalid price");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "stale price");
        uint8 dec = feed.decimals();
        return uint256(answer) * 10**(18 - dec);
    }
}