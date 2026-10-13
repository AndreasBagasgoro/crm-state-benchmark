import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../config.dart';
import '../driver/crm_actions.dart';
import '../driver/update_driver.dart';
import 'frame_recorder.dart';
import 'memory_sampler.dart';
import 'rebuild_counter.dart';
import 'result_writer.dart';
import 'stats.dart';

/// Alur satu sesi: kalibrasi → ukur → berhenti → tulis hasil.
///
/// 1. Tunggu `warmupSeconds` setelah *frame* pertama.
/// 2. Reset penghitung, aktifkan perekaman, jalankan *driver*.
/// 3. Tunggu `measureSeconds`.
/// 4. Hentikan *driver*, tunggu *frame* terakhir selesai, matikan perekaman.
/// 5. Tunggu `FrameTiming` yang tertunda, hitung ringkasan, tulis JSON,
///    cetak `BENCH_DONE <nama_file>` ke logcat.
class SessionRunner {
  SessionRunner({required this.actions, required this.library});

  final CrmActions actions;

  /// `provider` | `riverpod`.
  final String library;

  final FrameRecorder _frames = FrameRecorder();
  final MemorySampler _memory = MemorySampler();

  // Waktu tunggu FrameTiming yang dikirim berkelompok oleh engine (±1 s).
  static const _timingsDrain = Duration(seconds: 2);

  static void _log(String line) {
    // ignore: avoid_print
    print(line);
  }

  /// Dipanggil sekali dari `main()` setelah `runApp`.
  void startAfterFirstFrame() {
    BenchConfig.validate();
    _frames.install();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(run());
    });
  }

  Future<void> run() async {
    final code = BenchConfig.code(library);
    _log('BENCH_START $code ${BenchConfig.hz}Hz mode=${BenchConfig.mode}');

    await Future<void>.delayed(const Duration(seconds: BenchConfig.warmupSeconds));

    final driver = UpdateDriver(actions);
    RebuildCounter.reset();
    RebuildCounter.recording = true;
    _frames.start();
    _memory.start();
    driver.start();

    await Future<void>.delayed(const Duration(seconds: BenchConfig.measureSeconds));

    driver.stop();
    // Rebuild akibat pembaruan terakhir terjadi pada frame berikutnya.
    if (SchedulerBinding.instance.hasScheduledFrame) {
      await SchedulerBinding.instance.endOfFrame;
    }
    RebuildCounter.recording = false;
    _frames.stop();
    _memory.stop();

    await Future<void>.delayed(_timingsDrain);

    final result = _buildResult(code, driver);
    final fileName = '${code}_${BenchConfig.hz}hz_${_fileStamp(DateTime.now())}.json';
    final written = await ResultWriter.write(fileName, result);
    _log(written != null ? 'BENCH_DONE $written' : 'BENCH_DONE_NOFILE $fileName');
  }

  Map<String, Object?> _buildResult(String code, UpdateDriver driver) {
    final seconds = driver.elapsed.inMicroseconds / 1e6;
    final rebuilds = {
      for (final name in [...RebuildCounter.mainWidgets, RebuildCounter.customerTile])
        name: RebuildCounter.of(name),
    };
    final mainTotal = RebuildCounter.mainWidgets.fold<int>(0, (a, n) => a + rebuilds[n]!);
    final refresh = _refreshRate();

    return {
      'library': library,
      'mode': BenchConfig.mode,
      'code': code,
      'target_hz': BenchConfig.hz,
      'actual_hz': Stats.round(driver.actualHz, 2),
      'ticks': driver.ticks,
      'skipped_ticks': driver.skipped,
      'duration_s': Stats.round(seconds, 3),
      'warmup_s': BenchConfig.warmupSeconds,
      'rebuilds': rebuilds,
      'rebuilds_main_total': mainTotal,
      'rebuilds_per_s_main': Stats.round(mainTotal / seconds, 2),
      'rebuilds_per_s': {
        for (final e in rebuilds.entries) e.key: Stats.round(e.value / seconds, 2),
      },
      'frames': _frames.summary(refreshRate: refresh),
      'memory_mb': _memory.summary(),
      'device_refresh_hz': Stats.round(refresh, 2),
      'build_mode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      'seed': BenchConfig.seed,
      'timestamp': _isoWithOffset(DateTime.now()),
    };
  }

  static double _refreshRate() {
    final displays = PlatformDispatcher.instance.displays;
    final rate = displays.isEmpty ? 0.0 : displays.first.refreshRate;
    return rate > 0 ? rate : 60.0;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fileStamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

  static String _isoWithOffset(DateTime t) {
    final off = t.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final abs = off.abs();
    final base = t.toIso8601String().split('.').first;
    return '$base$sign${_two(abs.inHours)}:${_two(abs.inMinutes % 60)}';
  }
}
