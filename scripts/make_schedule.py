"""Fase 12.1 — jadwal sesi acak (16 konfigurasi × 10 repetisi = 160 baris).

    python scripts/make_schedule.py                       # results/schedule.csv
    python scripts/make_schedule.py --pilot               # results/pilot/schedule.csv (2 run/konfigurasi)

Urutan diacak dengan seed tetap (default 2026) sehingga dapat direproduksi.
Tidak menimpa jadwal yang sudah ada kecuali dengan --force.
"""

from __future__ import annotations

import argparse
import csv
import random

from common import CODES, FREQUENCIES, REPETITIONS, RESULTS

FIELDS = [
    "order", "code", "hz", "run", "status", "attempts",
    "temp_before_c", "temp_after_c", "battery_level", "started_at", "finished_at",
    "file", "note",
]


def make_rows(reps: int, seed: int) -> list[dict]:
    rows = [
        {"code": code, "hz": hz, "run": run}
        for code in CODES for hz in FREQUENCIES for run in range(1, reps + 1)
    ]
    random.Random(seed).shuffle(rows)
    for i, r in enumerate(rows, 1):
        r.update(order=i, status="pending", attempts=0)
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reps", type=int, default=None)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--pilot", action="store_true", help="jadwal pilot: 2 run, results/pilot/")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    reps = args.reps or (2 if args.pilot else REPETITIONS)
    out = (RESULTS / "pilot" if args.pilot else RESULTS) / "schedule.csv"
    if out.exists() and not args.force:
        raise SystemExit(f"{out} sudah ada. Pakai --force untuk menimpa.")
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = make_rows(reps, args.seed)
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} sesi -> {out}")


if __name__ == "__main__":
    main()
