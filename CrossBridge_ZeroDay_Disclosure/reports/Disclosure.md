# Responsible Disclosure — CrossBridge Critical Voucher Replay & Cross-Chain Replay

**Protocol:** CrossBridge (cross-chain token bridge)
**Reporter:** Web3 Security Expert
**Date:** 2026-10-22
**Severity:** Critical
**Platform:** Immunefi (confidential)
**Status:** Submitted — pending triage

## 1. Summary
A critical vulnerability in `CrossBridge.withdraw()` allows an attacker to replay a single validator-signed voucher an unlimited number of times, minting unbacked tokens on the destination chain. A second critical issue allows cross-chain replay of vouchers due to missing chain-id binding.

## 2. Vulnerability Details
### H-01 — Voucher replay (nonce not consumed)
- **Contract:** `CrossBridge.sol`
- **Function:** `withdraw(address to, uint256 amount, uint256 nonce, uint256 srcChainId, bytes sig)`
- **Root Cause:** The `nonce` is verified in the signature but never recorded as consumed. No `usedNonces` mapping exists.
- **Impact:** 100% of bridged TVL on destination chain mintable by anyone holding one valid voucher.
- **PoC:** `test_PoC_ReplayDrain` (10x replay), `test_PoC_BatchAmplification` (batch).

### H-02 — Cross-chain replay
- **Root Cause:** Verifier does not bind `srcChainId` to the destination `chainId`; a voucher signed for chain A can be replayed on chain B.
- **Impact:** Double-spend across chains.
- **PoC:** `test_PoC_CrossChainReplay`.

## 3. Impact Quantification
- **Funds at risk:** 100% of bridged TVL.
- **Attack cost:** One valid voucher (obtainable via normal bridge usage).
- **Reproducibility:** Trivial — single transaction / loop.
- **Blast radius:** All destination chains sharing the validator key.

## 4. Proof of Concept
Non-destructive: runs against local fork/test, no mainnet state touched.
```bash
forge test --match-test "test_PoC" -vvvv
```

## 5. Recommended Fix
```solidity
mapping(uint256 => bool) public usedNonces;
function withdraw(address to, uint256 amount, uint256 nonce, uint256 srcChainId, bytes memory sig) external {
    require(srcChainId != block.chainid, "same chain");
    require(!usedNonces[nonce], "nonce used");
    require(_verify(to, amount, nonce, srcChainId, sig), "invalid sig");
    usedNonces[nonce] = true;
    token.mint(to, amount);
}
```
Additionally: use EIP-712 typed data including `chainId`, `verifyingContract`, and a deadline; add a validator set with threshold signatures.

## 6. Remediation
See Recommended Fix section above.