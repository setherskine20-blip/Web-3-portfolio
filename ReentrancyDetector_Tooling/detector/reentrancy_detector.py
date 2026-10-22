#!/usr/bin/env python3
"""Custom static-analysis detector for reentrancy (CEI violations)."""
import os, re, sys, json

EXTERNAL_CALL = re.compile(r"\.(call|transfer|send|delegatecall)\s*[\({]|\.external\w*\s*\(")
STATE_WRITE = re.compile(r"\b\w+(\[[^\]]*\])?\s*(\+=|-=|\*=|/=|%=|(?<![\=!<>])=(?!=))")
FUNC_START = re.compile(r"function\s+(\w+)\s*\([^)]*\)\s*(public|external|internal|private)?[^{]*\{")

def scan_file(path):
    findings = []
    with open(path, encoding="utf-8", errors="ignore") as f:
        src = f.read()
    for m in FUNC_START.finditer(src):
        fname = m.group(1)
        start = m.end() - 1
        depth = 0; i = start
        while i < len(src):
            if src[i] == "{": depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0: break
            i += 1
        body = src[start:i+1]
        ext_positions = [mm.start() for mm in EXTERNAL_CALL.finditer(body)]
        write_positions = [mm.start() for mm in STATE_WRITE.finditer(body)]
        for ep in ext_positions:
            if any(w > ep for w in write_positions):
                findings.append({"file": path, "function": fname,
                    "issue": "External call before state write (CEI violation) - potential reentrancy",
                    "severity": "High"})
                break
    return findings

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    all_findings = []
    for root, _, files in os.walk(target):
        for fn in files:
            if fn.endswith(".sol"):
                all_findings.extend(scan_file(os.path.join(root, fn)))
    print(json.dumps(all_findings, indent=2))
    print(f"Total findings: {len(all_findings)}", file=sys.stderr)

if __name__ == "__main__":
    main()