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

### 5a. Pengambilan data manual per konfigurasi (PowerShell)

Alternatif dari `run_experiment.py` memakai fungsi di `scripts/bench_tools.ps1`. Kondisi HP tiap sesi dicatat ke `results/session_log.csv`.

`MODE` dan `HZ` ditanam ke APK saat build, jadi APK **wajib diganti setiap pindah konfigurasi**, tetapi tidak perlu diganti di antara sesi 1–10 dalam konfigurasi yang sama. Cukup install APK dari `builds/`; `flutter build` hanya perlu bila kode berubah.

**Setiap membuka terminal baru**

```powershell
cd C:\Users\Andreas\project\crm-state-benchmark
adb devices                      # HP harus berstatus "device"
. .\scripts\bench_tools.ps1      # memuat fungsi dan $PKG_A / $PKG_B
Kondisi-HP                       # level baterai, suhu, usb, thermal, RAM tersedia
$suhuAwal = Cek-Suhu             # patokan suhu hari ini
```

**Urutan per konfigurasi** (contoh A-N-10; ganti sesuai tabel di bawah)

1. Install APK: `adb install -r builds\A-N-10.apk`
2. Kosongkan hasil lama di HP: `Bersihkan-HP $PKG_A`
3. Sesi uji coba (opsional): `Jalankan-Sesi $PKG_A "A-N-10"` lalu `Ambil-Hasil $PKG_A "A-N-10" "demo"`
4. Sesi resmi 1: `Jalankan-Sesi $PKG_A "A-N-10" "resmi"`
5. Sesi resmi 2–10:
   ```powershell
   $kode = "A-N-10"; $pkg = $PKG_A; $jenis = "resmi"
   for ($i = 2; $i -le 10; $i++) {
     Start-Sleep -Seconds 10
     if (-not (Tunggu-Dingin $suhuAwal)) { break }   # berhenti bila $suhuAwal belum diisi
     Write-Host "=== $kode sesi $i | suhu $(Cek-Suhu) °C ===" -ForegroundColor Cyan
     Jalankan-Sesi $pkg $kode $jenis
   }
   ```
6. Salin hasil ke laptop: `Ambil-Hasil $PKG_A "A-N-10"` (harus tertulis 10 file di `results\raw\A-N-10`)
7. Isi sheet *Log Resmi* (nama file JSON + status), lalu `Bersihkan-HP $PKG_A`

**Daftar 16 konfigurasi**

| Kode | Library | `MODE` | `HZ` | Install APK | Paket | Jalankan sesi resmi | Ambil hasil |
|---|---|---|---|---|---|---|---|
| A-N-10 | Provider | naive | 10 | `adb install -r builds\A-N-10.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-N-10" "resmi"` | `Ambil-Hasil $PKG_A "A-N-10"` |
| A-N-20 | Provider | naive | 20 | `adb install -r builds\A-N-20.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-N-20" "resmi"` | `Ambil-Hasil $PKG_A "A-N-20"` |
| A-N-50 | Provider | naive | 50 | `adb install -r builds\A-N-50.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-N-50" "resmi"` | `Ambil-Hasil $PKG_A "A-N-50"` |
| A-N-90 | Provider | naive | 90 | `adb install -r builds\A-N-90.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-N-90" "resmi"` | `Ambil-Hasil $PKG_A "A-N-90"` |
| A-S-10 | Provider | selective | 10 | `adb install -r builds\A-S-10.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-S-10" "resmi"` | `Ambil-Hasil $PKG_A "A-S-10"` |
| A-S-20 | Provider | selective | 20 | `adb install -r builds\A-S-20.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-S-20" "resmi"` | `Ambil-Hasil $PKG_A "A-S-20"` |
| A-S-50 | Provider | selective | 50 | `adb install -r builds\A-S-50.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-S-50" "resmi"` | `Ambil-Hasil $PKG_A "A-S-50"` |
| A-S-90 | Provider | selective | 90 | `adb install -r builds\A-S-90.apk` | `$PKG_A` | `Jalankan-Sesi $PKG_A "A-S-90" "resmi"` | `Ambil-Hasil $PKG_A "A-S-90"` |
| B-N-10 | Riverpod | naive | 10 | `adb install -r builds\B-N-10.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-N-10" "resmi"` | `Ambil-Hasil $PKG_B "B-N-10"` |
| B-N-20 | Riverpod | naive | 20 | `adb install -r builds\B-N-20.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-N-20" "resmi"` | `Ambil-Hasil $PKG_B "B-N-20"` |
| B-N-50 | Riverpod | naive | 50 | `adb install -r builds\B-N-50.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-N-50" "resmi"` | `Ambil-Hasil $PKG_B "B-N-50"` |
| B-N-90 | Riverpod | naive | 90 | `adb install -r builds\B-N-90.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-N-90" "resmi"` | `Ambil-Hasil $PKG_B "B-N-90"` |
| B-S-10 | Riverpod | selective | 10 | `adb install -r builds\B-S-10.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-S-10" "resmi"` | `Ambil-Hasil $PKG_B "B-S-10"` |
| B-S-20 | Riverpod | selective | 20 | `adb install -r builds\B-S-20.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-S-20" "resmi"` | `Ambil-Hasil $PKG_B "B-S-20"` |
| B-S-50 | Riverpod | selective | 50 | `adb install -r builds\B-S-50.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-S-50" "resmi"` | `Ambil-Hasil $PKG_B "B-S-50"` |
| B-S-90 | Riverpod | selective | 90 | `adb install -r builds\B-S-90.apk` | `$PKG_B` | `Jalankan-Sesi $PKG_B "B-S-90" "resmi"` | `Ambil-Hasil $PKG_B "B-S-90"` |

Untuk sesi uji coba, hilangkan `"resmi"` pada `Jalankan-Sesi` dan tambahkan `"demo"` pada `Ambil-Hasil`. Pada loop sesi 2–10, ganti `$kode` dan `$pkg` sesuai baris tabel.

**Build ulang APK** (hanya bila kode di `apps/` atau `packages/` berubah); contoh B-S-90:

```powershell
cd apps\crm_benchmark_riverpod          # crm_benchmark_provider untuk kode A-*
flutter build apk --release --dart-define=MODE=selective --dart-define=HZ=90
adb install -r build\app\outputs\flutter-apk\app-release.apk
cd ..\..
```

**Perintah lain**

| Keperluan | Perintah |
|---|---|
| Cek suhu baterai saja | `Cek-Suhu` |
| Hentikan sesi yang sedang berjalan | `adb shell am force-stop $PKG_A` |
| Lihat file JSON di HP | `adb shell ls /sdcard/Android/data/$PKG_A/files/` |
| Cek isi JSON terakhir | `Get-Content (Get-ChildItem results\raw\A-N-10\*.json \| Select-Object -Last 1).FullName` |
| Ulangi konfigurasi dari sesi 1 (uji coba) | `Bersihkan-HP $PKG_A; Remove-Item results\demo\A-N-10 -Recurse -Force -ErrorAction SilentlyContinue` |
| Gabungkan dan periksa 160 JSON | `python scripts\gabung_data.py` |
| Analisis statistik Subbab 3.8 | `python scripts\analisis_data.py` |

### 6. Analisis (Fase 13)

```bash
.venv/Scripts/python -m nbconvert --to notebook --execute --inplace scripts/analysis.ipynb
# atau buka scripts/analysis.ipynb di VS Code / Jupyter
```

Output: `results/all_sessions.csv`, `results/tables/*.csv`, `results/figures/*.png`.
