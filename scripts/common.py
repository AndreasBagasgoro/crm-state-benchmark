"""Konstanta bersama untuk script eksperimen."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILDS = ROOT / "builds"
RESULTS = ROOT / "results"

LIBRARIES = {
    "A": {
        "library": "provider",
        "app_dir": ROOT / "apps" / "crm_benchmark_provider",
        "package": "com.skripsi.crm_benchmark_provider",
    },
    "B": {
        "library": "riverpod",
        "app_dir": ROOT / "apps" / "crm_benchmark_riverpod",
        "package": "com.skripsi.crm_benchmark_riverpod",
    },
}
MODES = {"N": "naive", "S": "selective"}
FREQUENCIES = [10, 20, 50, 90]
CODES = [f"{lib}-{mode}" for lib in LIBRARIES for mode in MODES]  # A-N, A-S, B-N, B-S
REPETITIONS = 10


def apk_path(code: str, hz: int) -> Path:
    return BUILDS / f"{code}-{hz}.apk"


def package_of(code: str) -> str:
    return LIBRARIES[code[0]]["package"]
