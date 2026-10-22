# Verification Results — CrossBridge Exploit PoCs

**Toolchain:** Foundry 1.8.6 (Solc 0.8.24)
**Date:** 2026-10-22

## Build
`forge build --root .` → SUCCESS

## Tests
`forge test --root .` → **3 passed, 0 failed**
- test_PoC_ReplayDrain (10x amplification)
- test_PoC_CrossChainReplay
- test_PoC_BatchAmplification