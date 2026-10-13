import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Menulis hasil sesi ke penyimpanan HP dan ke logcat.
///
/// File: `/sdcard/Android/data/<package>/files/<nama>.json` (diambil dengan
/// `adb pull`). JSON juga selalu dicetak ke logcat dengan penanda
/// `BENCH_JSON`, sebagai cadangan bila file tidak bisa ditulis/di-*pull*.
class ResultWriter {
  ResultWriter._();

  // Batas satu baris logcat ±4 KB; JSON dipecah per potongan.
  static const _chunk = 3000;

  /// Mengembalikan nama file bila berhasil ditulis, atau `null`.
  static Future<String?> write(String fileName, Map<String, Object?> result) async {
    final json = jsonEncode(result);
    _printJson(fileName, json);
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json, flush: true);
      return fileName;
    } catch (e) {
      _log('BENCH_ERROR gagal menulis $fileName: $e');
      return null;
    }
  }

  static void _printJson(String fileName, String json) {
    final parts = (json.length / _chunk).ceil();
    for (var i = 0; i < parts; i++) {
      final end = (i + 1) * _chunk;
      final part = json.substring(i * _chunk, end > json.length ? json.length : end);
      _log('BENCH_JSON $fileName ${i + 1}/$parts $part');
    }
  }

  static void _log(String line) {
    // `print` tetap masuk logcat (tag `flutter`) pada release build.
    // ignore: avoid_print
    print(line);
  }
}
