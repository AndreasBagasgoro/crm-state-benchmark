# Draf Penyelarasan Proposal dengan Implementasi

Draf teks untuk bagian proposal yang harus diselaraskan (plan §12). Silakan sesuaikan gaya bahasa dan penomorannya dengan dokumen proposal.

---

## Tabel 3.2 — Definisi operasional variabel terikat

| Variabel | Definisi | Cara ukur | Satuan |
|---|---|---|---|
| *Rebuild count* | Jumlah pemanggilan *build* pada tiga *widget* konsumen (CounterDisplay, CustomerList, SearchField) selama 30 detik pengukuran, dibagi durasi pengukuran | Penghitung di dalam `build()`/*builder* (`RebuildCounter`) | widget/detik |
| *Frame rendering time* | Rata-rata waktu kerja per *frame*, yaitu `buildDuration + rasterDuration`, untuk semua *frame* yang dimulai selama pengukuran | `SchedulerBinding.addTimingsCallback` (`FrameTiming`), dibatasi menurut nomor *frame*; divalidasi dengan DevTools Performance View (mode *profile*) | ms/frame |
| *Memory allocation* | Rata-rata *Resident Set Size* (RSS) proses selama 30 detik pengukuran (sampel tiap 1 detik) | `ProcessInfo.currentRss` (`dart:io`); divalidasi dengan DevTools Memory View / Android Profiler | MB |

## Tabel 3.3 — Variabel kontrol (tambahan)

| Variabel kontrol | Nilai |
|---|---|
| *Refresh rate* layar | Dikunci pada satu nilai (… Hz); fitur *adaptive/smooth display* dimatikan |
| Build mode | *release* |
| Kondisi perangkat | Mode pesawat, DND, kecerahan tetap, rotasi otomatis mati, *Stay awake*, baterai ≥ 80%, USB terhubung |
| Suhu baterai | Sesi dimulai hanya bila suhu ≤ suhu awal + 2 °C; suhu sebelum/sesudah sesi dicatat |
| Urutan sesi | Diacak dengan *seed* tetap (2026) |
| Data dan urutan pembaruan | *Mock data* 100 pelanggan dan urutan *event* dari `Random(42)`, identik di kedua aplikasi |

## Tabel 3.7 — Alat dan bahan (perubahan)

- Tambahkan `path_provider 2.1.5`, yang dipakai untuk menulis hasil sesi (JSON) ke penyimpanan HP.
- Tambahkan `statsmodels 0.14.4`, yang dipakai untuk koreksi Holm-Bonferroni.
- Ubah peran **Flutter DevTools** dan **Android Profiler**: keduanya menjadi *alat validasi instrumen* pada mode *profile*, bukan alat pengukuran utama, karena DevTools tidak dapat terhubung ke *release build*.
- Tambahkan **adb** (Android Debug Bridge) dan Python 3.12 (pandas, scipy, matplotlib) untuk otomasi dan analisis.

## Tabel 3.9 — Prosedur pengambilan data

1. Bangun 16 APK *release* (2 library × 2 pola × 4 frekuensi) dengan `--dart-define=MODE=… --dart-define=HZ=…`.
2. Siapkan perangkat sesuai variabel kontrol (Tabel 3.3).
3. Bangkitkan jadwal 160 sesi dengan urutan acak (*seed* 2026).
4. Untuk setiap sesi, *script* otomatis: memeriksa koneksi perangkat dan suhu baterai → memasang APK → menghentikan paksa aplikasi dan membersihkan logcat → menjalankan aplikasi → menunggu penanda `BENCH_DONE` (aplikasi sendiri menjalankan kalibrasi 5 detik dan pengukuran 30 detik) → mengambil file JSON hasil dengan `adb pull` → mencatat suhu → menghentikan aplikasi → *cooldown* 10 detik.
5. Sesi yang gagal atau terganggu dicatat penyebabnya di `session_log.md` lalu diulang.

## 3.7.3 — Cakupan *rebuild count*

> *Rebuild count* dihitung pada tiga *widget* konsumen *state*: CounterDisplay, CustomerList, dan SearchField. Ketiganya ada di kedua aplikasi dan menjadi titik tempat pola naif dan selektif berbeda. Pemanggilan *build* pada `CustomerTile` dicatat terpisah sebagai data pendukung. Jumlahnya bergantung pada ukuran layar, karena `ListView.builder` hanya membangun item yang terlihat, sehingga tidak dipakai sebagai metrik utama.

## 3.8.4 — *Effect size*

> Besar efek dihitung sesuai uji yang dipakai. Untuk Welch's t-test digunakan Hedges' g, yaitu Cohen's d dengan *pooled standard deviation* yang dikoreksi bias sampel kecil, J = 1 − 3/(4(n₁+n₂) − 9). Untuk Mann-Whitney U digunakan *rank-biserial correlation* r = 2U₁/(n₁n₂) − 1. Interpretasi mengikuti Cohen (1988). Untuk g: |g| < 0,2 dapat diabaikan, 0,2–0,5 kecil, 0,5–0,8 sedang, ≥ 0,8 besar. Untuk r: |r| < 0,1 dapat diabaikan, 0,1–0,3 kecil, 0,3–0,5 sedang, ≥ 0,5 besar. Tanda positif berarti nilai Provider lebih besar daripada Riverpod.

> Kelompok yang semua nilainya identik (variansi nol, misalnya *rebuild count* yang deterministik) tidak dapat diuji Shapiro-Wilk, sehingga diperlakukan tidak normal dan diuji dengan Mann-Whitney U.

## Keputusan K1 dan K2 (untuk Bab 3)

**K1 — StateNotifier.**
> Versi B memakai `StateNotifier` + `StateNotifierProvider`. Strukturnya sejajar dengan `ChangeNotifier` pada Versi A: satu kelas yang memegang *state* dan menyediakan metode pembaruan. Dengan begitu, perbedaan yang diukur berasal dari mekanisme notifikasi dan langganan, bukan dari perbedaan struktur kode. Pada Riverpod 3.x API ini berstatus *legacy* dan diimpor dari `package:flutter_riverpod/legacy.dart`, tetapi tetap tersedia dan berfungsi pada versi yang dipakai (3.3.2).

**K2 — Perbandingan default.**
> Kedua library dipakai dengan perilaku bawaannya. `Selector` pada Provider membandingkan nilai lama dan baru dengan `DeepCollectionEquality`, sedangkan `select()` pada Riverpod memakai operator `==`. Untuk nilai `int` dan `String` keduanya setara. Untuk `List<Customer>`, Provider membandingkan isi *list* (berhenti pada item pertama yang berbeda), sedangkan Riverpod hanya membandingkan identitas objek *list*. Karena setiap pembaruan *list* pada eksperimen ini mengganti tepat satu item, keduanya tetap memicu *rebuild*; perbedaannya ada pada biaya perbandingan. Perilaku ini diverifikasi dengan *widget test*.

## Bab 2 (2.3, 2.4, 2.5, Gambar 2.1–2.3) — klaim *rebuild* selektif

Yang perlu diperiksa di Bab 2:
- `Selector` dan `select()` **tidak mencegah pemanggilan *selector*** pada setiap notifikasi. Fungsi *selector* tetap dijalankan setiap kali *state* berubah; yang dicegah hanya *rebuild* bila nilai hasil seleksi sama.
- Pada Provider, `Consumer` dan `Selector` sama-sama berlangganan ke `ChangeNotifier` yang sama. `Selector` menyaring di sisi *widget* (membandingkan hasil *selector*).
- Pada Riverpod, `ref.watch(p.select(f))` berlangganan pada *provider* yang sama, dan penyaringan terjadi saat *listener* menerima nilai baru.
- *Rebuild* pada kedua library dijadwalkan ke *frame* berikutnya. Bila beberapa pembaruan terjadi dalam satu *frame* (misalnya 90 Hz pada layar 60 Hz), *widget* hanya dibangun sekali. Akibatnya *rebuild count* pola naif dapat lebih kecil dari jumlah *tick*.
