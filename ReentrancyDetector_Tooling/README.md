# Reentrancy Detector — Custom Static Analysis Tooling

**Type:** Custom Static Analysis Detector (Slither/Aderyn-style)
**Language:** Python
**Detects:** CEI violations, external-call-before-state-write

## Run
```bash
python detector/reentrancy_detector.py sample/
python tests/test_detector.py
```

