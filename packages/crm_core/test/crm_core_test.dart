import 'package:crm_core/crm_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implementasi [CrmActions] tanpa *library* untuk menguji *driver*.
class _PlainActions implements CrmActions {
  CrmState state = CrmState.initial();
  final List<CrmState> history = [];

  void _set(CrmState next) {
    history.add(state);
    state = next;
  }

  @override
  CrmState get current => state;
  @override
  void incrementCounter() => _set(state.incremented());
  @override
  void updateCustomer(int index, Customer updated) =>
      _set(state.withCustomerAt(index, updated));
  @override
  void updateSearchQuery(String query) => _set(state.withSearchQuery(query));
}

void main() {
  group('MockData', () {
    test('100 pelanggan, deterministik', () {
      final a = MockData.customers();
      final b = MockData.customers();
      expect(a, hasLength(100));
      expect([for (final c in a) c.status], [for (final c in b) c.status]);
      expect(a.first.name, 'Pelanggan 1');
      expect(a[25].company, 'PT Contoh 6');
    });
  });

  group('CrmState', () {
    test('withCustomerAt membuat list baru dan tidak mengubah list lama', () {
      final s0 = CrmState.initial();
      final c = s0.customers[3];
      final s1 = s0.withCustomerAt(3, c.copyWith(status: c.status.next));
      expect(identical(s0.customers, s1.customers), isFalse);
      expect(s0.customers[3].status, c.status);
      expect(s1.customers[3].status, c.status.next);
      expect(identical(s0.customers[4], s1.customers[4]), isTrue);
      expect(s1.counter, s0.counter);
      expect(s1.searchQuery, s0.searchQuery);
    });

    test('status.next selalu berbeda', () {
      for (final s in CustomerStatus.values) {
        expect(s.next, isNot(s));
      }
    });
  });

  group('UpdatePlan', () {
    List<String> trace() {
      final actions = _PlainActions();
      final plan = UpdatePlan();
      final out = <String>[];
      for (var i = 0; i < 300; i++) {
        plan.applyNext(actions);
        final s = actions.state;
        out.add('${s.counter}|${s.searchQuery}|'
            '${s.customers.map((c) => c.status.index).join()}');
      }
      return out;
    }

    test('urutan identik antar-sesi', () {
      expect(trace(), trace());
    });

    test('bergiliran counter → list → search, dan selalu mengubah nilai', () {
      final actions = _PlainActions();
      final plan = UpdatePlan();
      for (var tick = 0; tick < 900; tick++) {
        plan.applyNext(actions);
        final prev = actions.history.last;
        final next = actions.state;
        final counterChanged = prev.counter != next.counter;
        final listChanged = prev.customers != next.customers;
        final searchChanged = prev.searchQuery != next.searchQuery;
        switch (UpdatePlan.kindOf(tick)) {
          case UpdateKind.counter:
            expect([counterChanged, listChanged, searchChanged], [true, false, false]);
          case UpdateKind.customer:
            expect([counterChanged, listChanged, searchChanged], [false, true, false]);
            final diff = [
              for (var i = 0; i < 100; i++)
                if (prev.customers[i].status != next.customers[i].status) i,
            ];
            expect(diff, hasLength(1));
          case UpdateKind.search:
            expect([counterChanged, listChanged, searchChanged], [false, false, true]);
        }
      }
      expect(plan.ticks, 900);
    });
  });

  group('UpdateDriver', () {
    test('frekuensi aktual mendekati target (50 Hz, 1 detik)', () async {
      final actions = _PlainActions();
      final driver = UpdateDriver(actions, intervalMicros: 20000);
      driver.start();
      await Future<void>.delayed(const Duration(seconds: 1));
      driver.stop();
      // Toleransi lebar: test berjalan di mesin pengembang, bukan di HP.
      expect(driver.ticks, inInclusiveRange(45, 52));
      final ticks = driver.ticks;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(driver.ticks, ticks, reason: 'tidak ada tick setelah stop()');
    });

    test('90 Hz: frekuensi aktual mendekati target (2 detik)', () async {
      final driver = UpdateDriver(_PlainActions(), intervalMicros: 1000000 ~/ 90);
      driver.start();
      await Future<void>.delayed(const Duration(seconds: 2));
      driver.stop();
      expect(driver.actualHz, inInclusiveRange(85, 91));
    });
  });

  group('Stats', () {
    test('percentile sama dengan numpy (linear)', () {
      final xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      expect(Stats.percentile(xs, 50), closeTo(5.5, 1e-9));
      expect(Stats.percentile(xs, 90), closeTo(9.1, 1e-9));
      expect(Stats.percentile(xs, 99), closeTo(9.91, 1e-9));
      expect(Stats.mean(xs), 5.5);
      expect(Stats.percentile([], 50), 0);
    });
  });

  group('RebuildCounter', () {
    test('hanya menghitung saat recording', () {
      RebuildCounter.reset();
      RebuildCounter.recording = false;
      RebuildCounter.hit('X');
      RebuildCounter.recording = true;
      RebuildCounter.hit('X');
      RebuildCounter.hit('X');
      RebuildCounter.recording = false;
      expect(RebuildCounter.of('X'), 2);
    });
  });
}
