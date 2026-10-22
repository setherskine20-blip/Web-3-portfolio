# Verification Results — YieldMaxVault Invariant Suite

**Toolchain:** Foundry 1.8.6 (Solc 0.8.24)
**Date:** 2026-10-22

## Build
`forge build --root .` → SUCCESS

## Invariant Tests
`forge test --root .` → **1 suite passed (5 invariants)**
- invariant_shareAccounting
- invariant_solvency
- invariant_noValueCreation
- invariant_noOverWithdrawal
- invariant_totalSharesNonNegative

**Fuzz stats:** 256 runs × 50 depth = 128,000 calls; 326 reverts (all expected access-control reverts).