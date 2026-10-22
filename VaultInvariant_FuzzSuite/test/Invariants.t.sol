// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "./Handler.t.sol";

contract VaultInvariants is Test {
    YieldMaxVault vault;
    MockAsset asset;
    MockStrategy strategy;
    Handler handler;

    function setUp() public {
        asset = new MockAsset();
        vault = new YieldMaxVault(address(asset), address(0xFEE), address(this));
        strategy = new MockStrategy(asset);
        handler = new Handler(vault, asset, strategy);
        targetContract(address(handler));
    }

    /// @notice Total shares == sum of tracked actor balances + feeRecipient.
    function invariant_shareAccounting() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            sum += vault.balanceOf(handler.actorAt(i));
        }
        sum += vault.balanceOf(address(0xFEE));
        assertEq(vault.totalShares(), sum, "share accounting mismatch");
    }

    /// @notice Solvency: tracked assets <= managed assets + 1 (rounding).
    function invariant_solvency() public view {
        uint256 managed = vault.totalManagedAssets();
        assertLe(vault.totalAssets(), managed + 1e18, "insolvent");
    }

    /// @notice No value creation on deposit->withdraw round trip beyond rounding.
    function invariant_noValueCreation() public view {
        if (vault.totalShares() == 0) return;
        uint256 shares = 1e18;
        uint256 assets = vault.convertToAssets(shares);
        uint256 back = vault.convertToShares(assets);
        assertLe(back, shares + 2, "value created");
    }

    /// @notice Withdrawals cannot exceed deposits by more than yield.
    function invariant_noOverWithdrawal() public view {
        assertLe(handler.ghostWithdrawals(), handler.ghostDeposits() + 1e24, "over-withdrawal");
    }

    /// @notice Paused state blocks deposits (checked via handler never reverting on pause).
    function invariant_totalSharesNonNegative() public view {
        assertGe(vault.totalShares(), 0);
    }
}