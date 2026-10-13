# Plan: Aplikasi Benchmark CRM — Provider vs Riverpod

Rencana kerja pembangunan aplikasi *benchmark* untuk skripsi
"Perbandingan Overhead State Management antara Provider dan Riverpod pada Aplikasi Flutter dengan High-Frequency State Updates".

Status saat ini: **Langkah 1–4 selesai** (lingkungan dicek, repo dibuat, `crm_core` dan dua project aplikasi sudah di-`flutter create`).
**Fase 5–8, 9.1, 9.3, 10 (16 APK), serta script Fase 12–13 selesai (2026-10-13).** Langkah yang membutuhkan HP (uji `flutter run --release` di HP, 9.2, 9.4, Fase 11–12) dan analisis data riil (Fase 13) belum dijalankan. Penyesuaian terhadap plan dicatat di `README.md` § *Penyesuaian terhadap plan*.
Dokumen ini mencakup langkah 5 dan seterusnya.

---

## 0. Ringkasan Desain Eksperimen

| Komponen | Nilai |
|---|---|
| Variabel bebas 1 — *library* | Provider (Versi A), Riverpod (Versi B) |
| Variabel bebas 2 — pola konsumsi *state* | Naif (N), Selektif (S) |
| Perlakuan | A-N, A-S, B-N, B-S |
| Frekuensi *state update* | 10 Hz, 20 Hz, 50 Hz, 90 Hz |
| Konfigurasi | 2 × 2 × 4 = 16 |
| Repetisi | 10 per konfigurasi → **160 sesi** |
| Durasi sesi | 5 detik kalibrasi + 30 detik pengukuran + 10 detik *cooldown* |
| Variabel terikat | *rebuild count* (widget/detik), *frame rendering time* (ms/frame), *memory allocation* (MB) |
| Build mode | *release* |
| Data | *mock data* lokal, `Random(42)` |
| Analisis | Deskriptif → Shapiro-Wilk per kelompok → Welch's t-test / Mann-Whitney U → Holm-Bonferroni (24 perbandingan) → *effect size* |

### Kode perlakuan

| Kode | Library | Pola | Widget konsumen |
|---|---|---|---|
| A-N | Provider | Naif | `Consumer<CrmStateProvider>` |
| A-S | Provider | Selektif | `Selector<CrmStateProvider, T>` |
| B-N | Riverpod | Naif | `ref.watch(crmProvider)` |
| B-S | Riverpod | Selektif | `ref.watch(crmProvider.select(...))` |

### Prinsip yang tidak boleh dilanggar

1. **Satu-satunya kode yang berbeda antar-aplikasi adalah lapisan *state management*.** Model, data, UI, *driver*, dan instrumentasi berada di `crm_core`.
2. **`CrmState` *immutable*.** Setiap pembaruan membuat objek baru lewat `copyWith()`, termasuk *list* baru saat satu item berubah.
3. **Setiap pembaruan harus benar-benar mengubah nilai.** Kalau nilai baru sama dengan nilai lama, Selector/select akan menyaring notifikasi dan *rebuild count* menjadi bias.
4. **Urutan pembaruan identik di kedua aplikasi.** Urutan dibangkitkan dari *seed* tetap di `crm_core`.
5. **Pengukuran berjalan otomatis dari dalam aplikasi**, tanpa membuka DevTools saat sesi resmi.

---

## 1. Keputusan yang Harus Dikunci Sebelum Coding

- [x] **K1 — StateNotifier vs Notifier.** Di Riverpod 3, `StateNotifierProvider` adalah API *legacy* dan wajib diimpor dari `package:flutter_riverpod/legacy.dart`.
  - Opsi a: tetap StateNotifier (sesuai proposal, strukturnya cermin dengan ChangeNotifier). Tulis justifikasinya di Bab 3.
  - Opsi b: ganti ke `Notifier` + `NotifierProvider` (API modern). Revisi Tabel 3.1 dan 3.8.
  - *Default plan ini: opsi a.* → **Dipakai opsi a.**
- [x] **K2 — Perbandingan default Selector.** `Selector` milik Provider secara default membandingkan nilai dengan *deep equality* (`DeepCollectionEquality`), sedangkan `select()` Riverpod memakai `==`. Untuk *list* 100 item, ini berarti Provider melakukan perbandingan isi *list*.
  - Opsi a: biarkan *default* masing-masing *library* (mengukur perilaku bawaan; tulis sebagai karakteristik *library* di Bab 4).
  - Opsi b: samakan dengan `shouldRebuild: (prev, next) => !identical(prev, next)`.
  - *Default plan ini: opsi a, dan verifikasi perilakunya di Fase 6.* → **Dipakai opsi a; diverifikasi dari kode sumber provider 6.1.5+1 (`selector.dart`) dan widget test.**
- [x] **K3 — Instrumen pengukuran.** DevTools tidak bisa terhubung ke *release build*. Plan ini memakai instrumentasi di dalam aplikasi (jalan di *release*):
  - *Rebuild count* → counter di `build()`/*builder*
  - *Frame rendering time* → `SchedulerBinding.instance.addTimingsCallback` (`FrameTiming`)
  - *Memory* → `ProcessInfo.currentRss` disampling tiap 1 detik
  - DevTools (mode *profile*) hanya untuk **validasi** di Fase 6.
  - ⚠️ Tabel 3.2, 3.7, dan 3.9 di proposal masih menyebut DevTools/Android Profiler sebagai alat utama dan harus diselaraskan (lihat Fase 10).
- [x] **K4 — Definisi *memory allocation*.** Gunakan **rata-rata RSS selama 30 detik pengukuran (MB)** sebagai metrik utama; simpan juga RSS awal, akhir, dan maksimum. Selaraskan definisi di Tabel 3.2.
- [x] **K5 — Cakupan *rebuild count*.** Metrik utama = jumlah pemanggilan *build* pada tiga *widget* konsumen (CounterDisplay, CustomerList, SearchField) per detik. *Rebuild* `CustomerTile` dicatat terpisah sebagai data pendukung (jumlahnya bergantung ukuran layar karena `ListView.builder` hanya membangun item yang terlihat).

---

## 2. Fase 5 — Dependency & Konfigurasi Proyek

### 5.1 `packages/crm_core/pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  path_provider: 2.1.5   # untuk menulis hasil sesi ke penyimpanan HP
```

### 5.2 `apps/crm_benchmark_provider/pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: 6.1.5+1      # tanpa tanda ^
  crm_core:
    path: ../../packages/crm_core
```

### 5.3 `apps/crm_benchmark_riverpod/pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: 3.3.2   # tanpa tanda ^
  crm_core:
    path: ../../packages/crm_core
```

### 5.4 Langkah

- [x] `flutter pub add provider` / `flutter pub add flutter_riverpod` di masing-masing app
- [x] `flutter pub add path_provider` di `crm_core`
- [x] Tambahkan `crm_core` sebagai *path dependency* secara manual
- [x] Hapus `^` di semua versi agar terkunci
- [x] `flutter pub get` di ketiga folder
- [x] Hapus `test/widget_test.dart` bawaan di kedua app
- [ ] Ganti `lib/main.dart` dengan kerangka minimal dan pastikan `flutter run --release` jalan di HP — *`main.dart` sudah final dan `flutter build apk --release` berhasil; uji di HP belum (tidak ada perangkat terhubung)*
- [x] Commit, termasuk `pubspec.lock`

**Selesai bila:** kedua app jalan di HP dalam mode *release* dan bisa mengimpor `package:crm_core/crm_core.dart`.

---

## 3. Fase 6 — Membangun `crm_core` (Package Bersama)

### Struktur

```
packages/crm_core/lib/
├── crm_core.dart                    # export semua
└── src/
    ├── config.dart                  # baca --dart-define
    ├── model/
    │   ├── customer.dart
    │   └── crm_state.dart
    ├── data/
    │   └── mock_data.dart           # generator 100 pelanggan, Random(42)
    ├── driver/
    │   ├── crm_actions.dart         # interface yang diimplementasi tiap app
    │   ├── update_plan.dart         # urutan event deterministik
    │   └── update_driver.dart       # timer berbasis tenggat (lihat README)
    ├── instrumentation/
    │   ├── rebuild_counter.dart
    │   ├── frame_recorder.dart
    │   ├── memory_sampler.dart
    │   ├── session_runner.dart      # kalibrasi → ukur → stop → tulis hasil
    │   ├── result_writer.dart       # JSON ke penyimpanan HP
    │   └── stats.dart               # mean, median, persentil
    └── ui/
        ├── bench_app.dart           # MaterialApp bersama
        ├── dashboard_layout.dart    # susunan halaman (slot counter/search/list)
        ├── counter_view.dart
        ├── search_field_view.dart
        ├── customer_list_view.dart
        └── customer_tile.dart
```

### 6.1 Konfigurasi (`config.dart`)

`MODE` (naive | selective) dan `HZ` (10 | 20 | 50 | 90) dari `--dart-define`; `warmupSeconds = 5`, `measureSeconds = 30`, `seed = 42`; interval dalam mikrodetik (90 Hz → 11111 µs).

### 6.2 Model (`customer.dart`, `crm_state.dart`)

- `Customer`: `id`, `name`, `company`, `status` (`Prospek` / `Aktif` / `Nonaktif`), semua `final`.
- `CrmState`: `counter` (int), `customers` (List<Customer>, panjang 100), `searchQuery` (String), semua `final`, plus `copyWith()`.
- **Jangan override `==`/`hashCode` di `CrmState`.** Perbandingan bagian *state* cukup memakai `==` bawaan dari tiap properti: int dan String dibandingkan per nilai, List per identitas.

### 6.3 Data tiruan (`mock_data.dart`)

100 pelanggan, `Random(42)`.

### 6.4 Interface aksi (`crm_actions.dart`)

`incrementCounter()`, `updateCustomer(index, updated)`, `updateSearchQuery(query)`, `current`.

### 6.5 Urutan pembaruan (`update_plan.dart`) dan *driver* (`update_driver.dart`)

- Setiap *tick* memperbarui **satu** komponen secara bergantian: `tick % 3` → 0 = counter, 1 = list, 2 = search.
- Indeks item *list* dipilih dengan `Random(seed)` yang dibuat ulang setiap sesi, sehingga urutannya sama di semua sesi dan kedua app.
- Item yang diperbarui **harus berubah nilainya**, misalnya status digeser ke status berikutnya.
- *Search query* diambil bergiliran dari daftar kata (`'andi'`, `'budi'`, `'citra'`, …) sehingga **tidak pernah sama dengan nilai sebelumnya**.
- Catat jumlah *tick* untuk menghitung frekuensi aktual.

### 6.6 Instrumentasi

- **`rebuild_counter.dart`**: `CounterDisplay`, `CustomerList`, `SearchField` (utama) dan `CustomerTile` (pendukung).
- **`frame_recorder.dart`**: `addTimingsCallback`; *build*, *raster*, *build + raster* (mean, median, p90, p99); jumlah *frame*; *frame* yang melebihi anggaran.
- **`memory_sampler.dart`**: `ProcessInfo.currentRss` tiap 1 detik; awal, rata-rata, maksimum, akhir.
- **`session_runner.dart`**: tunggu 5 s → reset + rekam + `driver.start()` → 30 s → stop → ringkasan → JSON → `BENCH_DONE <nama_file>`.
- **`result_writer.dart`**: `getExternalStorageDirectory()`; JSON juga dicetak ke logcat (`BENCH_JSON`).

### 6.7 UI bersama

`DashboardLayout` (slot counter/search/list), `CounterView`, `SearchFieldView` (`readOnly`, controller di `didUpdateWidget`), `CustomerListView` (`ListView.builder`), `CustomerTile` (memanggil `RebuildCounter.hit('CustomerTile')`).

- [x] Semua file Fase 6 dibuat
- [x] Unit test `crm_core` (determinisme urutan, setiap pembaruan mengubah nilai, frekuensi driver, statistik)

**Selesai bila:** `crm_core` bisa dipakai oleh app contoh, dan `flutter analyze` bersih. ✅

---

## 4. Fase 7 — Implementasi Versi A (Provider)

```
apps/crm_benchmark_provider/lib/
├── main.dart
├── app.dart
├── state/crm_state_provider.dart
└── widgets/
    ├── naive/      (counter_consumer.dart, list_consumer.dart, search_consumer.dart)
    └── selective/  (counter_selector.dart, list_selector.dart, search_selector.dart)
```

- [x] 7.1 State (`ChangeNotifier implements CrmActions`)
- [x] 7.2 `main.dart` (`ChangeNotifierProvider.value`, pilih naif/selektif, `SessionRunner` setelah *frame* pertama)
- [x] 7.3 Widget konsumen

---

## 5. Fase 8 — Implementasi Versi B (Riverpod)

```
apps/crm_benchmark_riverpod/lib/
├── main.dart
├── app.dart
├── state/crm_state_notifier.dart
└── widgets/
    ├── naive/      (counter_watch.dart, list_watch.dart, search_watch.dart)
    └── selective/  (counter_select.dart, list_select.dart, search_select.dart)
```

- [x] 8.1 State (`StateNotifier` dari `legacy.dart`)
- [x] 8.2 `main.dart` (`ProviderContainer` + `UncontrolledProviderScope`)
- [x] 8.3 Widget konsumen

---

## 6. Fase 9 — Validasi Instrumen (sebelum data resmi)

### 9.1 Widget test di kedua app

| Skenario | Naif (A-N / B-N) | Selektif (A-S / B-S) |
|---|---|---|
| `incrementCounter()` lalu `pump()` | Ketiga widget +1 | Hanya `CounterDisplay` +1 |
| `updateCustomer()` lalu `pump()` | Ketiga widget +1 | Hanya `CustomerList` +1 |
| `updateSearchQuery()` lalu `pump()` | Ketiga widget +1 | Hanya `SearchField` +1 |

- [x] Test lulus di kedua app untuk kedua mode (kedua mode diuji dalam satu `flutter test`, tanpa `--dart-define`)
- [x] Bila hasil berbeda dari tabel, perbaiki sebelum lanjut.

### 9.2 Validasi silang dengan DevTools (mode *profile*)

- [ ] Jalankan satu konfigurasi per perlakuan dengan `flutter run --profile --dart-define=...`
- [ ] Bandingkan *frame time* dari `FrameRecorder` dengan Performance View DevTools, dan RSS dengan Memory View
- [ ] Simpan tangkapan layar sebagai bukti validitas instrumen (untuk Bab 4)

### 9.3 Verifikasi K2

- [x] Cek perilaku `Selector` untuk `List<Customer>` (perbandingan *deep* vs identitas) dan catat untuk Bab 4 — test `K2: ...` di kedua app; catatan di README dan `docs/penyelarasan_proposal.md`

### 9.4 Pilot test

- [ ] Jalankan 2–3 sesi untuk setiap konfigurasi (`make_schedule.py --pilot` → `run_experiment.py --pilot`)
- [ ] Periksa: frekuensi aktual (terutama 90 Hz), *rebuild count* masuk akal, suhu baterai tidak naik terus, file JSON berhasil di-*pull*
- [ ] Data pilot **tidak** dipakai dalam analisis (`results/pilot/` di-*gitignore*)

---

## 7. Fase 10 — Build 16 APK

- [x] `scripts/build_all.py` → `builds/A-N-10.apk … builds/B-S-90.apk`
- [x] `builds/manifest.csv` (kode, Hz, versi Flutter/Dart, commit hash, ukuran APK, sha256)
- [ ] Build ulang setelah pilot bila ada perubahan kode

---

## 8. Fase 11 — Persiapan Perangkat (setiap hari pengambilan data)

- [ ] Catat spesifikasi HP: merek, model, chipset, RAM, versi Android, *refresh rate* (di `versions.txt`)
- [ ] Kunci *refresh rate* (matikan *adaptive/smooth display* dan pilih satu nilai). Catat nilainya.
- [ ] Mode pesawat aktif, Wi-Fi/Bluetooth mati, notifikasi senyap / *Do Not Disturb*
- [ ] Kecerahan layar tetap (non-otomatis), rotasi otomatis mati
- [ ] *Developer options* → **Stay awake** aktif
- [ ] Tutup semua aplikasi lain
- [ ] Baterai ≥ 80%, kabel USB tetap terhubung sepanjang eksperimen

---

## 9. Fase 12 — Otomasi Pengambilan Data

- [x] 12.1 `scripts/make_schedule.py` (160 baris, seed 2026, `results/schedule.csv`)
- [x] 12.2 `scripts/run_experiment.py` (cek perangkat, suhu, install, force-stop, logcat, `BENCH_DONE`, pull, suhu setelah, cooldown, *resume*)
- [x] 12.3 Sesi gagal → `results/session_log.md` → diulang; `--redo` untuk sesi terganggu
- [ ] Jalankan 160 sesi

Package:
- Versi A: `com.skripsi.crm_benchmark_provider`
- Versi B: `com.skripsi.crm_benchmark_riverpod`

---

## 10. Fase 13 — Analisis Data (`scripts/analysis.ipynb`)

- [x] Notebook berisi langkah 1–10 (gabung JSON, frekuensi aktual, boxplot + *outlier*, deskriptif + CI 95%, Shapiro-Wilk, Welch/Mann-Whitney, Holm, *effect size*, grafik, ekspor) — diuji pada data sintetis
- [ ] Jalankan pada 160 file JSON riil

---

## 11. Struktur Repository Akhir

```
crm-state-benchmark/
├── apps/
│   ├── crm_benchmark_provider/
│   └── crm_benchmark_riverpod/
├── packages/
│   └── crm_core/
├── scripts/
│   ├── common.py
│   ├── build_all.py
│   ├── make_schedule.py
│   ├── run_experiment.py
│   ├── analysis.ipynb
│   └── requirements.txt
├── docs/
│   └── penyelarasan_proposal.md
├── builds/                  # 16 APK + manifest.csv (APK tidak di-commit)
├── results/
│   ├── schedule.csv
│   ├── session_log.md
│   ├── raw/                 # 160 file JSON
│   ├── all_sessions.csv
│   ├── tables/
│   └── figures/
├── versions.txt
├── plan.md
└── README.md
```

---

## 12. Bagian Proposal yang Perlu Diselaraskan dengan Plan Ini

Draf teks tersedia di `docs/penyelarasan_proposal.md`.

- [ ] **Tabel 3.2**: cara ukur *frame rendering time* → `FrameTiming` (validasi dengan DevTools mode *profile*); *memory allocation* → rata-rata RSS via `ProcessInfo.currentRss`
- [ ] **Tabel 3.7**: tambahkan `path_provider`, `statsmodels`; perjelas peran DevTools/Android Profiler sebagai alat validasi
- [ ] **Tabel 3.9**: prosedur menjadi otomatis via script adb (urutan acak, *force-stop*, *pull* JSON, cek suhu)
- [ ] **3.7.3**: cakupan *rebuild count* (tiga widget utama; `CustomerTile` sebagai data pendukung)
- [ ] **3.8.4**: metode *effect size* dan interpretasi Cohen yang benar
- [ ] **Tabel 3.3**: tambahkan *refresh rate* layar yang dikunci sebagai variabel kontrol
- [ ] **Bab 2 (2.3, 2.4, 2.5, Gambar 2.1–2.3)**: revisi klaim *rebuild* selektif
- [ ] Keputusan **K1** dan **K2** dicantumkan di Bab 3

---

## 13. Urutan Pengerjaan Ringkas

| No | Fase | Hasil | Status |
|---|---|---|---|
| 1 | Kunci keputusan K1–K5 | Desain final | ✅ |
| 2 | Fase 5 — dependency | Ketiga project terhubung | ✅ (uji di HP belum) |
| 3 | Fase 6 — `crm_core` | Model, data, *driver*, instrumentasi, UI | ✅ |
| 4 | Fase 7 — Versi A | A-N dan A-S jalan | ✅ (widget test) |
| 5 | Fase 8 — Versi B | B-N dan B-S jalan | ✅ (widget test) |
| 6 | Fase 9 — validasi + pilot | Instrumen terbukti benar | 9.1, 9.3 ✅; 9.2, 9.4 butuh HP |
| 7 | Fase 10 — build | 16 APK | ✅ |
| 8 | Fase 11–12 — pengambilan data | 160 file JSON | script ✅; butuh HP |
| 9 | Fase 13 — analisis | Tabel dan grafik untuk Bab 4 | notebook ✅; butuh data |
| 10 | Selaraskan proposal | Bab 2 dan Bab 3 konsisten dengan implementasi | draf ✅ |
