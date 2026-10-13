import 'dart:ui';

import 'package:flutter/scheduler.dart';

import 'stats.dart';

/// Merekam `FrameTiming` lewat `SchedulerBinding.addTimingsCallback`.
///
/// Pada *release build*, engine mengirim `FrameTiming` secara berkelompok
/// (hingga ±1 detik terlambat). Karena itu jendela pengukuran tidak ditentukan
/// dari waktu datangnya *callback*, melainkan dari nomor *frame*: setiap
/// *frame* yang dimulai saat perekaman aktif dicatat nomornya
/// (`PlatformDispatcher.frameData.frameNumber`), lalu hanya `FrameTiming`
/// dengan nomor dalam rentang itu yang dihitung.
class FrameRecorder {
  FrameRecorder({SchedulerBinding? binding})
      : _binding = binding ?? SchedulerBinding.instance;

  final SchedulerBinding _binding;
  final List<FrameTiming> _timings = [];
  // Cadangan bila nomor frame tidak tersedia: semua timing yang datang
  // selama perekaman aktif.
  final List<FrameTiming> _arrivalTimings = [];
  bool _installed = false;
  bool _recording = false;
  int? _firstFrame;
  int? _lastFrame;

  void install() {
    if (_installed) return;
    _installed = true;
    _binding.addTimingsCallback(_onTimings);
    _binding.addPersistentFrameCallback(_onFrame);
  }

  void start() {
    _timings.clear();
    _arrivalTimings.clear();
    _firstFrame = null;
    _lastFrame = null;
    _recording = true;
  }

  /// Menutup jendela pengukuran. `FrameTiming` yang masih tertunda tetap
  /// diterima; panggil [summary] setelah menunggu ±2 detik.
  void stop() {
    _recording = false;
  }

  void dispose() {
    if (!_installed) return;
    _binding.removeTimingsCallback(_onTimings);
    _installed = false;
  }

  void _onFrame(Duration _) {
    if (!_recording) return;
    final n = PlatformDispatcher.instance.frameData.frameNumber;
    if (n < 0) return;
    _firstFrame ??= n;
    _lastFrame = n;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_recording) _arrivalTimings.addAll(timings);
    if (_firstFrame == null) return;
    _timings.addAll(timings);
  }

  bool get _hasFrameWindow => _firstFrame != null && _lastFrame != null;

  /// `frame_number` atau `arrival` (cadangan).
  String get windowMethod => _hasFrameWindow ? 'frame_number' : 'arrival';

  List<FrameTiming> get windowTimings {
    if (!_hasFrameWindow) return List.of(_arrivalTimings);
    final first = _firstFrame!, last = _lastFrame!;
    return _timings
        .where((t) => t.frameNumber >= first && t.frameNumber <= last)
        .toList();
  }

  /// Ringkasan sesi (ms). [refreshRate] dipakai untuk anggaran *frame*.
  Map<String, Object> summary({required double refreshRate}) {
    final ts = windowTimings;
    final build = [for (final t in ts) t.buildDuration.inMicroseconds / 1000];
    final raster = [for (final t in ts) t.rasterDuration.inMicroseconds / 1000];
    final total = [for (var i = 0; i < ts.length; i++) build[i] + raster[i]];
    final span = [for (final t in ts) t.totalSpan.inMicroseconds / 1000];
    final budgetMs = 1000 / refreshRate;

    Map<String, double> describe(String key, List<double> xs) => {
          '${key}_mean_ms': Stats.round(Stats.mean(xs)),
          '${key}_median_ms': Stats.round(Stats.median(xs)),
          '${key}_p90_ms': Stats.round(Stats.percentile(xs, 90)),
          '${key}_p99_ms': Stats.round(Stats.percentile(xs, 99)),
          '${key}_max_ms': Stats.round(xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b)),
        };

    return {
      'count': ts.length,
      'expected_count': _hasFrameWindow ? _lastFrame! - _firstFrame! + 1 : -1,
      'window_method': windowMethod,
      ...describe('build', build),
      ...describe('raster', raster),
      // total = build + raster (waktu kerja UI + raster thread per frame)
      ...describe('total', total),
      // span = vsync start → raster finish (termasuk antrean antar-thread)
      ...describe('span', span),
      'budget_ms': Stats.round(budgetMs),
      // Definisi jank DevTools: build ATAU raster melebihi anggaran.
      'over_budget': [
        for (var i = 0; i < ts.length; i++)
          if (build[i] > budgetMs || raster[i] > budgetMs) 1,
      ].length,
      'over_budget_total': total.where((x) => x > budgetMs).length,
    };
  }
}
