# ThunderLoan LendingPool — Security Audit

**Client:** ThunderFi Labs
**Type:** Comprehensive Private Security Audit (DeFi Lending)
**Severity of findings:** 3 High / 2 Medium / 2 Low / 3 Info
**Auditor:** Web3 Security Expert

## Scope
`src/LendingPool.sol`, `src/PriceOracle.sol` (312 LoC)

## Key Findings
- H-01: Missing access control on `setOracle`
- H-02: Liquidation seizes all collateral, zeroes debt
- H-03: CEI violation in `withdraw`
- M-01: Precision loss in collateral valuation
- M-02: Stale price acceptance

## Run
```bash
forge test -vvv
forge coverage
slither . --exclude-dependencies
```

