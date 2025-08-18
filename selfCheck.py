# selfCheck.py
import os, re, time, json, subprocess, sys
from pathlib import Path

import requests  # pip install requests

def detect_project_root():
    """
    Works from either:
      C:\...\backdoor420\
      C:\...\backdoor420\hybrid_malware_platform\
    Returns Path to hybrid_malware_platform
    """
    cwd = Path.cwd()
    # Case A: you're already inside hybrid_malware_platform
    if (cwd / "backend" / "app.py").exists():
        return cwd

    # Case B: you're one level above
    candidate = cwd / "hybrid_malware_platform"
    if (candidate / "backend" / "app.py").exists():
        return candidate

    # Case C: search one level down for safety
    for p in cwd.iterdir():
        if p.is_dir() and (p / "backend" / "app.py").exists():
            return p

    raise SystemExit("[X] Could not locate project root containing backend/app.py")

ROOT = detect_project_root()
BACKEND = ROOT / "backend"
FRONTEND = ROOT / "frontend"
UPLOADS = BACKEND / "uploads"
REPORTS = BACKEND / "reports"

REQUIRED = [
    BACKEND / "app.py",
    BACKEND / "config.py",
    BACKEND / "requirements.txt",
    BACKEND / "modules",
    BACKEND / "utils",
    BACKEND / "uploads",
    BACKEND / "reports",
    FRONTEND / "templates" / "index.html",
    FRONTEND / "templates" / "analysis_result.html",
]

def assert_path(p: Path):
    if not p.exists():
        raise SystemExit(f"[X] Missing: {p}")

def launch_flask():
    # Start the app as a subprocess; capture stdout/stderr for diagnostics
    return subprocess.Popen(
        [sys.executable, str(BACKEND / "app.py")],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

def wait_server(port=5000, timeout=10.0):
    url = f"http://127.0.0.1:{port}/"
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            r = requests.get(url, timeout=0.5)
            if r.status_code == 200:
                return True
        except Exception:
            time.sleep(0.2)
    return False

def dump_proc_output(proc, max_lines=200):
    try:
        out = proc.stdout.read() if proc.stdout else ""
    except Exception:
        out = ""
    if out:
        lines = out.strip().splitlines()[-max_lines:]
        print("\n[Flask output tail]")
        print("\n".join(lines))

def main():
    print("== Part-2 Self Check ==")
    # 1) Structure
    for p in REQUIRED:
        assert_path(p)
    print("[OK] Structure")

    # 2) .env
    env_path = BACKEND / ".env"
    if not env_path.exists():
        env_path.write_text(
            "UPLOAD_FOLDER=uploads\nREPORT_FOLDER=reports\nSECRET_KEY=dev_secret\n",
            encoding="utf-8"
        )
        print("[INFO] Created backend/.env placeholder")
    else:
        print("[OK] .env exists")

    # 3) Launch server
    proc = launch_flask()
    try:
        if not wait_server():
            print("[X] Flask did not come up on :5000")
            dump_proc_output(proc)
            proc.kill()
            sys.exit(1)
        print("[OK] Server up")

        # 4) GET /
        r = requests.get("http://127.0.0.1:5000/", timeout=2)
        assert r.status_code == 200, f"/ status {r.status_code}"
        print("[OK] GET /")

        # 5) POST /upload (dummy ps1)
        dummy = ROOT / "dummy.ps1"
        dummy.write_text("Write-Output 'hello'\n", encoding="ascii")
        with open(dummy, "rb") as fh:
            r2 = requests.post(
                "http://127.0.0.1:5000/upload",
                files={"file": ("dummy.ps1", fh, "text/plain")},
                timeout=5,
                allow_redirects=False
            )
        assert r2.status_code in (200, 302), f"/upload status {r2.status_code}"
        print("[OK] POST /upload")

        # 6) Verify SHA256-named file + JSON
        sha_files = [p.name for p in UPLOADS.iterdir() if re.fullmatch(r"[0-9a-f]{64}", p.name)]
        if not sha_files:
            print("[X] No SHA256 file saved in uploads")
            dump_proc_output(proc)
            sys.exit(1)
        sha = sorted(sha_files)[-1]
        meta = UPLOADS / f"{sha}.json"
        if not meta.exists():
            print(f"[X] Metadata JSON missing: {meta}")
            dump_proc_output(proc)
            sys.exit(1)
        print(f"[OK] Stored as {sha} (+json)")

        # 7) Detail page
        r3 = requests.get(f"http://127.0.0.1:5000/detail/{sha}", timeout=3)
        assert r3.status_code == 200, f"/detail status {r3.status_code}"
        print("[OK] GET /detail/<sha>")

        print("\nAll Part-2 checks passed ✅")
    finally:
        try:
            proc.kill()
        except Exception:
            pass

if __name__ == "__main__":
    main()
