# Comprehensive Security Audit Report

**Client:** ThunderFi Labs — LendingPool Protocol
**Auditor:** Web3 Security Expert
**Date:** 2026-10-22
**Commit:** a1b2c3d (main)
**Scope:** `src/LendingPool.sol`, `src/PriceOracle.sol` (312 LoC)
**Methodology:** Manual review + Foundry PoC verification + threat modeling

## 1. Executive Summary
ThunderFi LendingPool is a collateralized lending protocol (WETH collateral, USDC borrow). The audit identified **3 High**, **2 Medium**, **2 Low**, and **3 Informational** findings. The protocol must not be deployed to mainnet without remediation of all High/Medium findings. Critical issues: missing access control on oracle setter, liquidation logic that seizes collateral without debt repayment, and CEI violations.

## 2. Threat Model
| Actor | Capability | Goal |
|-------|-----------|------|
| Depositor | Deposit/withdraw/borrow/repay | Earn yield, access liquidity |
| Liquidator | Liquidate unhealthy positions | Profit from liquidation bonus |
| Admin (none defined) | — | Should be multisig + timelock |
| Attacker | Flash loans, oracle manipulation, reentrancy | Drain protocol |

**Trust assumptions:** Chainlink feed is trusted; admin key is trusted (currently undefined → any caller).

## 3. Risk Matrix
| ID | Title | Severity | Likelihood | Impact |
|----|-------|----------|------------|--------|
| H-01 | Missing access control on `setOracle` | High | High | Critical |
| H-02 | Liquidation seizes all collateral, zeroes debt | High | Medium | Critical |
| H-03 | CEI violation in `withdraw` | High | Medium | High |
| M-01 | Precision loss in collateral valuation | Medium | High | Medium |
| M-02 | Stale price acceptance (1h threshold) | Medium | Low | Medium |
| L-01 | Missing interest accrual | Low | High | Low |
| L-02 | No close factor on liquidation | Low | Medium | Medium |
| I-01 | No events for oracle change | Info | — | — |
| I-02 | Magic numbers not constants | Info | — | — |
| I-03 | Missing NatSpec on internal helpers | Info | — | — |

## 4. Detailed Findings

### H-01 — Missing access control on `setOracle`
**Root Cause:** `setOracle` is `external` with no modifier.
**Impact:** Attacker sets a fake oracle returning arbitrary price → borrows against phantom collateral → drains pool.
**PoC:** `test_PoC_H01_UnauthorizedOracleSet`
**Remediation:** `onlyRole(ORACLE_ADMIN_ROLE)` + timelock (48h) + multisig.

### H-02 — Liquidation seizes all collateral, zeroes debt
**Root Cause:** `liquidate` transfers all collateral and zeroes debt without requiring repayment or enforcing close factor.
**Impact:** Attacker liquidates any position for full collateral extraction; bad debt.
**PoC:** `test_PoC_H02_LiquidationSeizeAll`
**Remediation:** Require `repayAmount <= closeFactor * debt`; transfer collateral proportional to repaid debt plus bonus; partial liquidation.

### H-03 — CEI violation in `withdraw`
**Root Cause:** `collateralToken.transfer` before `p.collateral -= amount`.
**Impact:** Reentrancy (mitigated by nonReentrant but pattern is unsafe if guard removed).
**Remediation:** State update before external call; keep ReentrancyGuard.

### M-01 — Precision loss
**Root Cause:** `(collateral * price) / 1e18 / 1e12` truncates twice.
**Remediation:** `(collateral * price) / 1e30` in one step; use PRBMath.

### M-02 — Stale price
**Root Cause:** 1-hour staleness threshold too loose for volatile assets.
**Remediation:** 15-min threshold + deviation check vs. previous round.

### L-01 — Missing interest accrual
**Root Cause:** `borrow` doesn't accrue interest on outstanding debt.
**Remediation:** Accrue interest at start of every state-changing function.

### L-02 — No close factor
**Root Cause:** Liquidation can repay 100% of debt in one tx.
**Remediation:** Cap at 50% close factor.

## 5. Gas Optimization
- Pack `Position` struct (collateral, debt fit in 2 slots).
- Use custom errors (saves ~200 gas per revert).
- Cache `oracle.getPrice()` in `borrow`.

## 6. Remediation Verification
Post-fix re-audit required. Run:
```bash
forge test -vvv
forge coverage  # target 100%
slither . --exclude-dependencies
aderyn .
```

## 7. Appendix — Test Coverage
| Function | Unit | Fuzz | Invariant |
|----------|------|------|-----------|
| deposit | ✓ | ✓ | ✓ |
| withdraw | ✓ | ✓ | — |
| borrow | ✓ | ✓ | ✓ |
| repay | ✓ | ✓ | — |
| liquidate | ✓ | ✓ | — |
| setOracle | ✓ | — | — |