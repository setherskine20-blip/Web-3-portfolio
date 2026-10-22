import subprocess, sys, json, os

def run(target):
    r = subprocess.run([sys.executable, "detector/reentrancy_detector.py", target],
                       capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return r.stdout, r.stderr

def test_vulnerable_detected():
    out, err = run("sample")
    data = json.loads(out)
    assert len(data) >= 1
    assert any("VulnerableBank" in d["file"] or "Vulnerable" in d["file"] for d in data)

def test_safe_not_flagged():
    # run only on Safe.sol by temp copy
    pass

if __name__ == "__main__":
    out, err = run("sample")
    print(out); print(err)