import 'dart:async';

import '../config.dart';
import 'crm_actions.dart';
import 'update_plan.dart';

/// Menjalankan [UpdatePlan] pada frekuensi target.
///
/// Tidak memakai `Timer.periodic` karena timer Dart beresolusi milidetik:
/// periode 11111 µs (90 Hz) akan dibulatkan menjadi 11 ms (≈90,9 Hz).
/// Sebagai gantinya, tenggat *tick* ke-n dihitung dalam mikrodetik
/// (`n × interval`) dan setiap timer dijadwalkan ke tenggat berikutnya,
/// sehingga galat pembulatan tidak terakumulasi.
class UpdateDriver {
  UpdateDriver(this.actions, {int? intervalMicros})
      : intervalMicros = intervalMicros ?? BenchConfig.intervalMicros;

  final CrmActions actions;
  final int intervalMicros;
  final UpdatePlan plan = UpdatePlan();
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  int _nextDueMicros = 0;
  bool _running = false;

  /// Jumlah *tick* yang sudah dijalankan.
  int get ticks => plan.ticks;

  /// *Tick* yang terlewat karena *thread* UI tertinggal lebih dari satu
  /// interval (tidak dikejar secara beruntun).
  int skipped = 0;

  /// Waktu dari *tick* pertama sampai [stop] dipanggil.
  Duration get elapsed => _clock.elapsed;

  /// Frekuensi aktual: jumlah *tick* dibagi lama berjalan.
  double get actualHz {
    final s = _clock.elapsedMicroseconds / 1e6;
    return s == 0 ? 0 : ticks / s;
  }

  void start() {
    if (_running) return;
    _running = true;
    _clock
      ..reset()
      ..start();
    _nextDueMicros = 0;
    _onTick();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void _onTick() {
    if (!_running) return;
    plan.applyNext(actions);
    _scheduleNext();
  }

  void _scheduleNext() {
    _nextDueMicros += intervalMicros;
    final now = _clock.elapsedMicroseconds;
    if (now - _nextDueMicros > intervalMicros) {
      // Tertinggal lebih dari satu interval: lompati, jangan kejar beruntun.
      final behind = (now - _nextDueMicros) ~/ intervalMicros;
      skipped += behind;
      _nextDueMicros += behind * intervalMicros;
    }
    final delay = _nextDueMicros - now;
    // Pembulatan ke atas ke milidetik agar timer tidak menyala sebelum tenggat.
    final delayMs = delay <= 0 ? 0 : (delay + 999) ~/ 1000;
    _timer = Timer(Duration(milliseconds: delayMs), _onTick);
  }
}
