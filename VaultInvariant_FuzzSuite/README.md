# YieldMaxVault — Invariant & Stateful Fuzzing Suite

**Client:** YieldMax Protocol
**Type:** Invariant & Stateful Fuzzing Test Suite
**Vault features:** ERC-4626, performance fee (high-water mark), management fee, strategy hook, pause

## Invariants Verified
- Share accounting (totalShares == sum balances)
- Solvency (tracked <= managed)
- No value creation on round-trip
- No over-withdrawal
- Total shares non-negative

## Run
```bash
forge test --match-contract VaultInvariants -vvv
```

