# Web3 Security Portfolio

Portfolio of production-grade Web3 security deliverables by a Web3 Security Expert.

## Projects
1. **ThunderLoan_Audit_PoC** — DeFi lending protocol security audit (3H/2M/2L). Verified: 5/5 tests pass, 65.75% line coverage.
2. **VaultInvariant_FuzzSuite** — ERC-4626 vault invariant fuzzing (5 invariants, 128k calls). All pass.
3. **PrimeLend_PrivateAudit** — AMM + lending audit (4H/3M/3L). 4/4 tests pass.
4. **CrossBridge_ZeroDay_Disclosure** — Critical bridge vulnerability disclosure. 3/3 PoCs pass.
5. **ReentrancyDetector_Tooling** — Custom CEI detector (verified working).
6. **TokenForge_ERC20_Scaffold** — Production ERC-20 (Permit, Votes, Pausable). 9/9 tests pass, 87% coverage.

## Reproduce
Each Foundry project requires:
```bash
forge install foundry-rs/forge-std
forge test --root .
forge coverage --root .
```
Foundry 1.8.6+ recommended.

## Verification
Each project includes a `VERIFICATION.md` with build/test/coverage results.