import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/naive/counter_watch.dart';
import 'widgets/naive/list_watch.dart';
import 'widgets/naive/search_watch.dart';
import 'widgets/selective/counter_select.dart';
import 'widgets/selective/list_select.dart';
import 'widgets/selective/search_select.dart';

class RiverpodBenchApp extends StatelessWidget {
  const RiverpodBenchApp({super.key, required this.container, required this.selective});

  final ProviderContainer container;
  final bool selective;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: selective
          ? const BenchApp(
              title: 'CRM Benchmark · Riverpod',
              counter: CounterSelect(),
              search: SearchSelect(),
              list: ListSelect(),
            )
          : const BenchApp(
              title: 'CRM Benchmark · Riverpod',
              counter: CounterWatch(),
              search: SearchWatch(),
              list: ListWatch(),
            ),
    );
  }
}
