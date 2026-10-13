import 'dart:async';
import 'dart:io';

import 'stats.dart';

/// Menyampling RSS proses (`ProcessInfo.currentRss`) setiap [period].
class MemorySampler {
  MemorySampler({this.period = const Duration(seconds: 1)});

  final Duration period;
  final List<double> samplesMb = [];
  Timer? _timer;

  static double currentRssMb() => ProcessInfo.currentRss / (1024 * 1024);

  void start() {
    samplesMb
      ..clear()
      ..add(currentRssMb()); // RSS awal
    _timer = Timer.periodic(period, (_) => samplesMb.add(currentRssMb()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    samplesMb.add(currentRssMb()); // RSS akhir
  }

  /// Metrik utama: `mean` (rata-rata RSS selama pengukuran, MB).
  Map<String, Object> summary() {
    if (samplesMb.isEmpty) return {};
    return {
      'start': Stats.round(samplesMb.first, 2),
      'mean': Stats.round(Stats.mean(samplesMb), 2),
      'max': Stats.round(samplesMb.reduce((a, b) => a > b ? a : b), 2),
      'end': Stats.round(samplesMb.last, 2),
      'samples': [for (final s in samplesMb) Stats.round(s, 2)],
    };
  }
}
