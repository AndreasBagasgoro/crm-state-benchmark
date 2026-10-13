import 'package:crm_benchmark_riverpod/app.dart';
import 'package:crm_benchmark_riverpod/state/crm_state_notifier.dart';
import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 9.1: memastikan pola konsumsi sesuai definisi.
///
/// | Aksi                 | Naif (B-N)     | Selektif (B-S)          |
/// |----------------------|----------------|-------------------------|
/// | incrementCounter()   | ketiga +1      | hanya CounterDisplay +1 |
/// | updateCustomer()     | ketiga +1      | hanya CustomerList +1   |
/// | updateSearchQuery()  | ketiga +1      | hanya SearchField +1    |
void main() {
  Map<String, int> snapshot() =>
      {for (final n in RebuildCounter.mainWidgets) n: RebuildCounter.of(n)};

  Map<String, int> delta(Map<String, int> before) =>
      {for (final n in RebuildCounter.mainWidgets) n: RebuildCounter.of(n) - before[n]!};

  Map<String, int> only(String name) =>
      {for (final n in RebuildCounter.mainWidgets) n: n == name ? 1 : 0};

  const all = {'CounterDisplay': 1, 'CustomerList': 1, 'SearchField': 1};
  const none = {'CounterDisplay': 0, 'CustomerList': 0, 'SearchField': 0};

  for (final selective in [false, true]) {
    final code = selective ? 'B-S' : 'B-N';

    testWidgets('$code: rebuild sesuai pola konsumsi', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(crmProvider.notifier);
      await tester.pumpWidget(RiverpodBenchApp(container: container, selective: selective));
      RebuildCounter.reset();
      RebuildCounter.recording = true;
      addTearDown(() => RebuildCounter.recording = false);

      var before = snapshot();
      await tester.pump();
      expect(delta(before), none, reason: 'tanpa pembaruan tidak ada rebuild');

      before = snapshot();
      state.incrementCounter();
      await tester.pump();
      expect(delta(before), selective ? only('CounterDisplay') : all);

      before = snapshot();
      final c = state.current.customers[0];
      state.updateCustomer(0, c.copyWith(status: c.status.next));
      await tester.pump();
      expect(delta(before), selective ? only('CustomerList') : all);

      before = snapshot();
      state.updateSearchQuery('andi');
      await tester.pump();
      expect(delta(before), selective ? only('SearchField') : all);

      // UI benar-benar menampilkan nilai baru.
      expect(find.text('andi'), findsOneWidget);
      expect(state.current.counter, 1);
    });

    testWidgets('$code: UpdatePlan 30 tick → rebuild sesuai pola', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(crmProvider.notifier);
      await tester.pumpWidget(RiverpodBenchApp(container: container, selective: selective));
      RebuildCounter.reset();
      RebuildCounter.recording = true;
      addTearDown(() => RebuildCounter.recording = false);

      final plan = UpdatePlan();
      for (var i = 0; i < 30; i++) {
        plan.applyNext(state);
        await tester.pump();
      }
      expect(
        snapshot(),
        selective
            ? {'CounterDisplay': 10, 'CustomerList': 10, 'SearchField': 10}
            : {'CounterDisplay': 30, 'CustomerList': 30, 'SearchField': 30},
      );
      expect(RebuildCounter.of(RebuildCounter.customerTile), greaterThan(0));
    });
  }

  group('K2: perbandingan default select()', () {
    testWidgets('List baru dengan isi sama TETAP memicu rebuild (==, identitas)',
        (tester) async {
      final listProvider = StateProvider<List<int>>((ref) => [1, 2, 3]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var builds = 0;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (_, ref, __) {
          ref.watch(listProvider.select((l) => l));
          builds++;
          return const SizedBox();
        }),
      ));
      expect(builds, 1);

      final n = container.read(listProvider.notifier);
      n.state = List.of(n.state); // objek baru, isi sama
      await tester.pump();
      expect(builds, 2, reason: 'select() membandingkan dengan ==');

      n.state = [1, 2, 4]; // isi berbeda
      await tester.pump();
      expect(builds, 3);
    });
  });
}
