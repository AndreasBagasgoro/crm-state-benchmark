import 'dart:math';

import '../config.dart';
import 'crm_actions.dart';

enum UpdateKind { counter, customer, search }

/// Urutan pembaruan deterministik. Dibuat ulang setiap sesi, sehingga urutan
/// event identik di semua sesi dan di kedua aplikasi.
///
/// *Tick* ke-n memperbarui satu komponen secara bergantian (`n % 3`):
/// 0 = counter, 1 = satu item *list*, 2 = *search query*. Setiap pembaruan
/// menjamin nilai baru berbeda dari nilai lama.
class UpdatePlan {
  UpdatePlan({int seed = BenchConfig.seed}) : _rng = Random(seed);

  static const queries = [
    'andi', 'budi', 'citra', 'dewi', 'eko', 'fajar', 'gita', 'hadi', //
  ];

  final Random _rng;
  int _tick = 0;

  int get ticks => _tick;

  static UpdateKind kindOf(int tick) => UpdateKind.values[tick % 3];

  /// Menjalankan pembaruan untuk *tick* berikutnya.
  void applyNext(CrmActions actions) {
    final tick = _tick++;
    switch (kindOf(tick)) {
      case UpdateKind.counter:
        actions.incrementCounter();
      case UpdateKind.customer:
        final customers = actions.current.customers;
        final i = _rng.nextInt(customers.length);
        final c = customers[i];
        actions.updateCustomer(i, c.copyWith(status: c.status.next));
      case UpdateKind.search:
        // Bergiliran dari 8 kata → tidak pernah sama dengan nilai sebelumnya.
        actions.updateSearchQuery(queries[(tick ~/ 3) % queries.length]);
    }
  }
}
