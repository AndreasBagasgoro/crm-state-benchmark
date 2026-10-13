/// Konfigurasi sesi benchmark, dibaca dari `--dart-define` saat build.
///
/// ```
/// flutter build apk --release --dart-define=MODE=selective --dart-define=HZ=50
/// ```
class BenchConfig {
  BenchConfig._();

  /// `naive` | `selective`.
  static const mode = String.fromEnvironment('MODE', defaultValue: 'naive');

  /// Frekuensi *state update* target: 10 | 20 | 50 | 90.
  static const hz = int.fromEnvironment('HZ', defaultValue: 10);

  static const warmupSeconds = 5;
  static const measureSeconds = 30;
  static const seed = 42;

  /// Jumlah pelanggan pada data tiruan.
  static const customerCount = 100;

  static bool get isSelective => mode == 'selective';

  /// Interval antar-*tick* dalam mikrodetik (90 Hz → 11111 µs).
  static int get intervalMicros => 1000000 ~/ hz;

  static Duration get interval => Duration(microseconds: intervalMicros);

  /// Kode perlakuan, misalnya `A-S` (Provider, Selektif).
  static String code(String library) {
    final lib = library == 'provider' ? 'A' : 'B';
    final pattern = isSelective ? 'S' : 'N';
    return '$lib-$pattern';
  }

  static void validate() {
    if (mode != 'naive' && mode != 'selective') {
      throw StateError('MODE harus naive atau selective, bukan "$mode"');
    }
    if (hz <= 0 || hz > 1000) {
      throw StateError('HZ tidak valid: $hz');
    }
  }
}
