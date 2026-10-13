"""Fase 10 — build 16 APK release (2 library × 2 pola × 4 frekuensi).

    python scripts/build_all.py                 # semua
    python scripts/build_all.py --only A-N-90   # satu konfigurasi
    python scripts/build_all.py --skip-existing

Hasil: builds/<kode>-<hz>.apk dan builds/manifest.csv.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import shutil
import subprocess
import sys
import time
from datetime import datetime

from common import BUILDS, CODES, FREQUENCIES, LIBRARIES, MODES, ROOT, apk_path

FLUTTER = shutil.which("flutter") or "flutter"
MANIFEST_FIELDS = [
    "code", "library", "mode", "hz", "apk", "size_bytes", "sha256",
    "flutter_version", "dart_version", "commit", "dirty", "built_at", "build_seconds",
]


def run(cmd: list[str], cwd=ROOT, capture=False) -> str:
    res = subprocess.run(cmd, cwd=cwd, text=True, capture_output=capture, encoding="utf-8")
    if res.returncode != 0:
        if capture:
            sys.stderr.write(res.stdout + res.stderr)
        raise SystemExit(f"Gagal: {' '.join(cmd)}")
    return res.stdout if capture else ""


def flutter_versions() -> tuple[str, str]:
    out = run([FLUTTER, "--version", "--machine"], capture=True)
    import json
    info = json.loads(out[out.index("{"):])
    return info["frameworkVersion"], info["dartSdkVersion"]


def git_state() -> tuple[str, bool]:
    try:
        commit = run(["git", "rev-parse", "--short", "HEAD"], capture=True).strip()
    except SystemExit:
        commit = "no-commit"
    dirty = bool(run(["git", "status", "--porcelain", "--", "apps", "packages"], capture=True).strip())
    return commit, dirty


def sha256(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest() -> dict[str, dict]:
    path = BUILDS / "manifest.csv"
    if not path.exists():
        return {}
    with open(path, newline="", encoding="utf-8") as f:
        return {f"{r['code']}-{r['hz']}": r for r in csv.DictReader(f)}


def save_manifest(rows: dict[str, dict]) -> None:
    order = {f"{c}-{hz}": i for i, (c, hz) in enumerate((c, hz) for c in CODES for hz in FREQUENCIES)}
    with open(BUILDS / "manifest.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        for key in sorted(rows, key=lambda k: order.get(k, 999)):
            w.writerow(rows[key])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="mis. A-N-90 B-S-10")
    ap.add_argument("--skip-existing", action="store_true")
    args = ap.parse_args()

    BUILDS.mkdir(exist_ok=True)
    flutter_ver, dart_ver = flutter_versions()
    commit, dirty = git_state()
    if dirty:
        print("PERINGATAN: ada perubahan belum di-commit di apps/ atau packages/ "
              "(kolom 'dirty' di manifest = True).")
    manifest = load_manifest()

    targets = [(c, hz) for c in CODES for hz in FREQUENCIES]
    if args.only:
        targets = [(c, hz) for c, hz in targets if f"{c}-{hz}" in set(args.only)]

    for code, hz in targets:
        dest = apk_path(code, hz)
        if args.skip_existing and dest.exists():
            print(f"[lewati] {dest.name}")
            continue
        lib = LIBRARIES[code[0]]
        mode = MODES[code[2]]
        print(f"\n=== {code} {hz} Hz ({lib['library']}, {mode}) ===", flush=True)
        t0 = time.time()
        run([FLUTTER, "build", "apk", "--release",
             f"--dart-define=MODE={mode}", f"--dart-define=HZ={hz}"], cwd=lib["app_dir"])
        src = lib["app_dir"] / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        shutil.copy2(src, dest)
        manifest[f"{code}-{hz}"] = {
            "code": code, "library": lib["library"], "mode": mode, "hz": hz,
            "apk": dest.name, "size_bytes": dest.stat().st_size, "sha256": sha256(dest),
            "flutter_version": flutter_ver, "dart_version": dart_ver,
            "commit": commit, "dirty": dirty,
            "built_at": datetime.now().astimezone().isoformat(timespec="seconds"),
            "build_seconds": round(time.time() - t0, 1),
        }
        save_manifest(manifest)
        print(f"-> {dest.relative_to(ROOT)} ({dest.stat().st_size / 1e6:.1f} MB)")

    print(f"\nSelesai. Manifest: {(BUILDS / 'manifest.csv').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
