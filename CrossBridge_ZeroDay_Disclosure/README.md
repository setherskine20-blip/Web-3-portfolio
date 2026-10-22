# CrossBridge — Critical Zero-Day Disclosure

**Protocol:** CrossBridge (cross-chain token bridge)
**Type:** Production Zero-Day Bug Bounty Disclosure
**Severity:** Critical (2 findings)
**Reporter:** Web3 Security Expert

## Findings
- H-01: Voucher replay (nonce not consumed) → 10x amplification PoC
- H-02: Cross-chain replay (missing chain-id binding)

## Run
```bash
forge test --match-test "test_PoC" -vvvv
```

