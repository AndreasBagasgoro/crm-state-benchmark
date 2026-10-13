"""Fase 12.2 — menjalankan sesi sesuai jadwal lewat adb.

    python scripts/run_experiment.py                     # results/schedule.csv
    python scripts/run_experiment.py --pilot             # results/pilot/schedule.csv
    python scripts/run_experiment.py --limit 5           # hanya 5 sesi lalu berhenti
    python scripts/run_experiment.py --redo 17 42 --note "notifikasi muncul"
    python scripts/run_experiment.py --dry-run

Untuk setiap baris berstatus pending (lalu failed, sampai --max-attempts):
cek perangkat → cek suhu baterai → install APK → force-stop + logcat -c →
start → tunggu BENCH_DONE → adb pull JSON → catat suhu → force-stop →
cooldown → tandai done. Jadwal disimpan setelah setiap sesi, sehingga script
bisa dihentikan (Ctrl+C) dan dilanjutkan kapan saja.
"""

from __future__ import annotations

import argparse
import csv
import json
import queue
import re
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

from common import RESULTS, ROOT, apk_path, package_of
from make_schedule import FIELDS

ADB = "adb"


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


class Adb:
    def __init__(self, serial: str | None, dry_run: bool):
        self.prefix = [ADB] + (["-s", serial] if serial else [])
        self.dry_run = dry_run

    def __call__(self, *args: str, check=True, timeout=120) -> str:
        cmd = self.prefix + list(args)
        if self.dry_run:
            print("  $", " ".join(cmd))
            return ""
        res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=timeout)
        if check and res.returncode != 0:
            raise RuntimeError(f"{' '.join(cmd)}\n{res.stdout}{res.stderr}")
        return res.stdout

    def shell(self, *args: str, **kw) -> str:
        return self("shell", *args, **kw)

    def logcat(self) -> subprocess.Popen:
        cmd = self.prefix + ["logcat", "-v", "tag", "-s", "flutter:I", "AndroidRuntime:E"]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace")


def connected_devices() -> list[str]:
    out = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout
    return [l.split("\t")[0] for l in out.splitlines()[1:] if l.endswith("\tdevice")]


def battery(adb: Adb) -> tuple[float | None, int | None]:
    out = adb.shell("dumpsys", "battery", check=False)
    t = re.search(r"temperature:\s*(\d+)", out)
    lvl = re.search(r"level:\s*(\d+)", out)
    return (int(t.group(1)) / 10 if t else None, int(lvl.group(1)) if lvl else None)


def load(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k in FIELDS:
            r.setdefault(k, "")
    return rows


def save(path: Path, rows: list[dict]) -> None:
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    tmp.replace(path)


def log_session(log_path: Path, row: dict, message: str) -> None:
    new = not log_path.exists()
    with open(log_path, "a", encoding="utf-8") as f:
        if new:
            f.write("# Log Sesi Bermasalah\n\n| Waktu | Order | Kode | Hz | Run | Keterangan |\n"
                    "|---|---|---|---|---|---|\n")
        f.write(f"| {now_iso()} | {row['order']} | {row['code']} | {row['hz']} | "
                f"{row['run']} | {message.replace('|', '/')} |\n")


def wait_for_cool(adb: Adb, threshold: float, max_wait: int) -> str:
    waited = 0
    while True:
        temp, _ = battery(adb)
        if temp is None or temp <= threshold:
            return ""
        if waited >= max_wait:
            return f"suhu {temp:.1f}°C > ambang {threshold:.1f}°C setelah menunggu {waited}s"
        print(f"  suhu baterai {temp:.1f}°C > {threshold:.1f}°C, menunggu 30 s ...", flush=True)
        time.sleep(30)
        waited += 30


def run_session(adb: Adb, row: dict, raw_dir: Path, timeout: int) -> tuple[Path, str]:
    """Menjalankan satu sesi. Mengembalikan (path JSON, sumber: file|logcat)."""
    code, hz = row["code"], int(row["hz"])
    pkg = package_of(code)
    apk = apk_path(code, hz)
    if not apk.exists() and not adb.dry_run:
        raise RuntimeError(f"APK tidak ditemukan: {apk} (jalankan build_all.py)")

    adb("install", "-r", str(apk), timeout=180)
    adb.shell("am", "force-stop", pkg)
    adb("logcat", "-c")
    adb.shell("input", "keyevent", "KEYCODE_WAKEUP", check=False)

    dest = raw_dir / f"{code}_{hz}_r{row['run']}.json"
    if adb.dry_run:
        adb.shell("am", "start", "-n", f"{pkg}/.MainActivity")
        return dest, "dry-run"

    proc = adb.logcat()
    lines: queue.Queue[str] = queue.Queue()
    threading.Thread(target=lambda: [lines.put(l) for l in proc.stdout], daemon=True).start()
    try:
        adb.shell("am", "start", "-n", f"{pkg}/.MainActivity")
        chunks: dict[int, str] = {}
        done_file = None
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                line = lines.get(timeout=1).rstrip()
            except queue.Empty:
                continue
            if "AndroidRuntime" in line and "FATAL" in line:
                raise RuntimeError(f"aplikasi crash: {line}")
            m = re.search(r"BENCH_JSON (\S+) (\d+)/(\d+) (.*)$", line)
            if m:
                chunks[int(m.group(2))] = m.group(4)
                total = int(m.group(3))
                continue
            m = re.search(r"BENCH_DONE(_NOFILE)? (\S+)", line)
            if m:
                done_file = m.group(2)
                break
            if "BENCH_" in line:
                print("  " + line.split(": ", 1)[-1], flush=True)
        else:
            raise RuntimeError(f"timeout {timeout}s tanpa BENCH_DONE")
    finally:
        proc.kill()

    # 1) adb pull file JSON; 2) cadangan: susun ulang dari logcat.
    remote = f"/sdcard/Android/data/{pkg}/files/{done_file}"
    try:
        adb("pull", remote, str(dest))
        source = "file"
    except RuntimeError as e:
        if not chunks or len(chunks) != total:
            raise RuntimeError(f"adb pull gagal dan BENCH_JSON tidak lengkap: {e}")
        dest.write_text("".join(chunks[i] for i in sorted(chunks)), encoding="utf-8")
        source = "logcat"

    data = json.loads(dest.read_text(encoding="utf-8"))
    if data.get("code") != code or int(data.get("target_hz", -1)) != hz:
        raise RuntimeError(f"JSON tidak cocok: {data.get('code')} {data.get('target_hz')} Hz")
    return dest, source


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pilot", action="store_true", help="pakai results/pilot/")
    ap.add_argument("--serial", help="serial perangkat (adb -s)")
    ap.add_argument("--limit", type=int, help="jumlah sesi maksimum pada pemanggilan ini")
    ap.add_argument("--timeout", type=int, default=60, help="detik menunggu BENCH_DONE")
    ap.add_argument("--cooldown", type=int, default=10)
    ap.add_argument("--temp-margin", type=float, default=2.0,
                    help="ambang = suhu awal + margin (°C)")
    ap.add_argument("--temp-baseline", type=float, help="suhu awal; default: suhu saat script mulai")
    ap.add_argument("--max-temp-wait", type=int, default=1200, help="detik maksimum menunggu dingin")
    ap.add_argument("--max-attempts", type=int, default=3)
    ap.add_argument("--redo", nargs="*", type=int, metavar="ORDER",
                    help="kembalikan baris ini ke pending (sesi terganggu)")
    ap.add_argument("--note", default="", help="keterangan untuk --redo")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    base = RESULTS / "pilot" if args.pilot else RESULTS
    sched_path = base / "schedule.csv"
    raw_dir = base / "raw"
    log_path = base / "session_log.md"
    if not sched_path.exists():
        raise SystemExit(f"{sched_path} belum ada. Jalankan make_schedule.py dulu.")
    raw_dir.mkdir(parents=True, exist_ok=True)
    rows = load(sched_path)

    if args.dry_run:
        # Dry run tidak pernah menulis jadwal; cukup tampilkan 2 sesi pertama.
        globals()["save"] = lambda *_: None
        globals()["log_session"] = lambda *_: None
        args.limit = args.limit or 2

    if args.redo:
        for r in rows:
            if int(r["order"]) in args.redo:
                log_session(log_path, r, f"diulang manual: {args.note or '-'} (status lama {r['status']})")
                r["status"] = "pending"
                r["attempts"] = "0"
        save(sched_path, rows)
        print(f"{len(args.redo)} baris dikembalikan ke pending.")
        return

    if not args.dry_run:
        devices = connected_devices()
        if args.serial and args.serial not in devices or not devices:
            raise SystemExit(f"Perangkat tidak terhubung (adb devices: {devices}).")
        if len(devices) > 1 and not args.serial:
            raise SystemExit(f"Lebih dari satu perangkat: {devices}. Pakai --serial.")
    adb = Adb(args.serial, args.dry_run)

    baseline = args.temp_baseline
    if baseline is None and not args.dry_run:
        baseline, _ = battery(adb)
    threshold = (baseline or 0) + args.temp_margin
    if baseline is not None:
        print(f"Suhu awal {baseline:.1f}°C, ambang {threshold:.1f}°C")

    def todo() -> list[dict]:
        pend = [r for r in rows if r["status"] == "pending"]
        fail = [r for r in rows if r["status"] == "failed"
                and int(r["attempts"] or 0) < args.max_attempts]
        return pend + fail

    done_now = 0
    try:
        while (queue_ := todo()) and (args.limit is None or done_now < args.limit):
            row = queue_[0]
            total_done = sum(r["status"] == "done" for r in rows)
            print(f"\n[{total_done + 1}/{len(rows)}] order {row['order']}: "
                  f"{row['code']} {row['hz']} Hz run {row['run']}", flush=True)

            if not args.dry_run and not connected_devices():
                raise SystemExit("Perangkat terputus. Sambungkan lalu jalankan ulang.")

            note = "" if args.dry_run else wait_for_cool(adb, threshold, args.max_temp_wait)
            temp_before, level = (None, None) if args.dry_run else battery(adb)
            row.update(attempts=int(row["attempts"] or 0) + 1, started_at=now_iso(),
                       temp_before_c=temp_before or "", battery_level=level or "")
            pkg = package_of(row["code"])
            try:
                dest, source = run_session(adb, row, raw_dir, args.timeout)
                row["status"] = "done"
                row["file"] = str(dest.relative_to(ROOT)).replace("\\", "/")
                notes = [n for n in [note, "json dari logcat" if source == "logcat" else ""] if n]
                row["note"] = "; ".join(notes)
                print(f"  OK -> {row['file']}")
            except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
                row["status"] = "failed"
                row["note"] = str(e).splitlines()[0][:200]
                log_session(log_path, row, f"gagal (percobaan {row['attempts']}): {row['note']}")
                print(f"  GAGAL: {row['note']}", file=sys.stderr)
            finally:
                if not args.dry_run:
                    row["temp_after_c"] = battery(adb)[0] or ""
                adb.shell("am", "force-stop", pkg, check=False)
                row["finished_at"] = now_iso()
                save(sched_path, rows)
            done_now += 1
            if not args.dry_run:
                time.sleep(args.cooldown)
    except KeyboardInterrupt:
        save(sched_path, rows)
        print("\nDihentikan. Jalankan ulang untuk melanjutkan.")
        return

    counts = {s: sum(r["status"] == s for r in rows) for s in ("done", "pending", "failed")}
    print(f"\nRingkasan: {counts}")


if __name__ == "__main__":
    main()
