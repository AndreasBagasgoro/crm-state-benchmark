# CRM State Benchmark — Provider vs Riverpod

Aplikasi *benchmark* untuk skripsi *"Perbandingan Overhead State Management antara
Provider dan Riverpod pada Aplikasi Flutter dengan High-Frequency State Updates"*.

| Kode | Library | Pola | Widget konsumen |
|---|---|---|---|
| A-N | Provider 6.1.5+1 | Naif | `Consumer<CrmStateProvider>` |
| A-S | Provider 6.1.5+1 | Selektif | `Selector<CrmStateProvider, T>` |
| B-N | Riverpod 3.3.2 | Naif | `ref.watch(crmProvider)` |
| B-S | Riverpod 3.3.2 | Selektif | `ref.watch(crmProvider.select(...))` |

4 perlakuan × 4 frekuensi (10, 20, 50, 90 Hz) × 10 repetisi = **160 sesi**.
Setiap sesi berlangsung 5 detik kalibrasi, 30 detik pengukuran, lalu 10 detik *cooldown*.
Versi lengkap perangkat lunak ada di [`versions.txt`](versions.txt), rencana kerja di [`plan.md`](plan.md).

## Struktur

```
apps/crm_benchmark_provider/   Versi A: hanya lapisan state (ChangeNotifier + Consumer/Selector)
apps/crm_benchmark_riverpod/   Versi B: hanya lapisan state (StateNotifier + watch/select)
packages/crm_core/             Semua kode lain: model, data, driver, instrumentasi, UI
scripts/                       build_all.py, make_schedule.py, run_experiment.py, analysis.ipynb
builds/                        16 APK (tidak di-commit) + manifest.csv
results/                       schedule.csv, session_log.md, raw/*.json, all_sessions.csv, tables/, figures/
docs/penyelarasan_proposal.md  Draf teks untuk menyelaraskan Bab 2–3 proposal
```

## Keputusan desain (K1–K5)

| | Keputusan | Implementasi |
|---|---|---|
| K1 | **StateNotifier** (opsi a), diimpor dari `package:flutter_riverpod/legacy.dart` | `apps/crm_benchmark_riverpod/lib/state/crm_state_notifier.dart` |
| K2 | **Default bawaan library** (opsi a): `Selector` memakai `DeepCollectionEquality`, sedangkan `select()` memakai `==` | Dibuktikan oleh test `K2: ...` di kedua app |
| K3 | Instrumentasi di dalam aplikasi (jalan di *release*); DevTools hanya untuk validasi | `packages/crm_core/lib/src/instrumentation/` |
| K4 | *Memory* = **rata-rata RSS** selama 30 detik (MB); start/max/end/samples ikut disimpan | `memory_sampler.dart` |
| K5 | *Rebuild count* utama = CounterDisplay + CustomerList + SearchField per detik; `CustomerTile` sebagai data pendukung | `rebuild_counter.dart` |

**Konsekuensi K2 yang perlu dicatat di Bab 4.** Setiap pembaruan *list* membuat `List` baru dengan satu item berbeda, sehingga kedua library tetap melakukan *rebuild*. Bedanya ada pada biaya perbandingan. Saat counter atau search berubah, `List` masih objek yang sama, dan `DeepCollectionEquality` langsung keluar lewat pemeriksaan `identical`. Saat *list* berubah, Provider membandingkan item satu per satu (dengan `==`, yaitu identitas `Customer`) sampai menemukan item yang berbeda. Riverpod cukup membandingkan identitas `List`.

## Penyesuaian terhadap plan

- **Driver tidak memakai `Timer.periodic`.** Timer Dart beresolusi milidetik, jadi 11111 µs (90 Hz) akan dibulatkan menjadi 11 ms (≈90,9 Hz). `UpdateDriver` menghitung tenggat *tick* ke-n dalam mikrodetik dan menjadwalkan timer satu per satu, sehingga galat tidak menumpuk. *Tick* yang tertinggal lebih dari satu interval dilompati dan dicatat sebagai `skipped_ticks`; tidak dikejar beruntun.
- **Jendela `FrameTiming` berdasarkan nomor *frame*.** Pada *release*, engine mengirim `FrameTiming` secara berkelompok, hingga ±1 detik terlambat. `FrameRecorder` mencatat nomor *frame* (`PlatformDispatcher.frameData.frameNumber`) yang dimulai selama pengukuran, lalu hanya menghitung `FrameTiming` dengan nomor itu. Setelah *driver* berhenti, runner menunggu 2 detik agar kelompok terakhir ikut masuk.
- **Transisi *state* ada di `CrmState`** (`incremented`, `withCustomerAt`, `withSearchQuery`). Cara membuat objek baru jadi identik di kedua app; yang berbeda hanya mekanisme notifikasinya.
- **`BenchApp` (MaterialApp + DashboardLayout) di `crm_core`.** Kedua app hanya mengisi tiga slot.
- **Widget test mencakup kedua mode dalam satu kali jalan.** Widget aplikasi menerima parameter `selective`, sedangkan `main()` mengisinya dari `BenchConfig.isSelective`. `--dart-define` tidak diperlukan untuk `flutter test`.
- **JSON hasil juga selalu dicetak ke logcat** (`BENCH_JSON`, dipecah per 3000 karakter). Bila `adb pull` gagal, runner menyusun ulang file dari logcat.
- Kolom tambahan pada JSON: `skipped_ticks`, `rebuilds_per_s` per widget, `frames.{build,raster,total,span}_{mean,median,p90,p99,max}_ms`, `frames.expected_count`, `frames.window_method`, `over_budget` (definisi DevTools: build **atau** raster > anggaran) dan `over_budget_total` (build + raster > anggaran), `memory_mb.samples`, `build_mode`.

## Reproduksi eksperimen

### 0. Persiapan sekali

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r scripts/requirements.txt     # Windows
cd packages/crm_core && flutter pub get && flutter test && cd -
cd apps/crm_benchmark_provider && flutter pub get && flutter test && cd -
cd apps/crm_benchmark_riverpod && flutter pub get && flutter test && cd -
```

### 1. Validasi di HP (Fase 9)

```bash
# Cek cepat satu konfigurasi (log BENCH_* muncul di konsol)
cd apps/crm_benchmark_provider
flutter run --release --dart-define=MODE=naive --dart-define=HZ=50

# Validasi silang dengan DevTools (mode profile)
flutter run --profile --dart-define=MODE=selective --dart-define=HZ=90
```

Bandingkan `frames.total_mean_ms` di JSON dengan Performance View DevTools, dan `memory_mb` dengan Memory View. Simpan tangkapan layarnya.

### 2. Build 16 APK (Fase 10)

```bash
python scripts/build_all.py            # builds/A-N-10.apk ... builds/B-S-90.apk + manifest.csv
```

Jalankan setelah semua perubahan kode di-commit, agar kolom `commit` di manifest bermakna (`dirty=False`).

### 3. Pilot (Fase 9.4, data tidak dianalisis)

```bash
python scripts/make_schedule.py --pilot          # 32 sesi → results/pilot/schedule.csv
python scripts/run_experiment.py --pilot
```

### 4. Persiapan perangkat (Fase 11)

Kunci *refresh rate*, aktifkan mode pesawat dan DND, gunakan kecerahan tetap, matikan rotasi otomatis, aktifkan **Stay awake**, tutup aplikasi lain, pastikan baterai ≥ 80%, dan biarkan USB terhubung. Catat spesifikasi HP di `versions.txt`.

### 5. Pengambilan data (Fase 12)

```bash
python scripts/make_schedule.py                  # 160 sesi acak (seed 2026) → results/schedule.csv
python scripts/run_experiment.py                 # bisa dihentikan (Ctrl+C) dan dilanjutkan
python scripts/run_experiment.py --limit 40      # mis. dibagi per hari
python scripts/run_experiment.py --redo 17 --note "notifikasi sistem muncul"   # ulangi sesi terganggu
```

Sesi gagal dicatat di `results/session_log.md` dan dicoba ulang otomatis, maksimal 3 percobaan. Suhu baterai sebelum dan sesudah sesi disimpan di `schedule.csv`.

### 6. Analisis (Fase 13)

```bash
.venv/Scripts/python -m nbconvert --to notebook --execute --inplace scripts/analysis.ipynb
# atau buka scripts/analysis.ipynb di VS Code / Jupyter
```

Output: `results/all_sessions.csv`, `results/tables/*.csv`, `results/figures/*.png`.
