import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'state/crm_state_provider.dart';
import 'widgets/naive/counter_consumer.dart';
import 'widgets/naive/list_consumer.dart';
import 'widgets/naive/search_consumer.dart';
import 'widgets/selective/counter_selector.dart';
import 'widgets/selective/list_selector.dart';
import 'widgets/selective/search_selector.dart';

class ProviderBenchApp extends StatelessWidget {
  const ProviderBenchApp({super.key, required this.state, required this.selective});

  final CrmStateProvider state;
  final bool selective;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CrmStateProvider>.value(
      value: state,
      child: selective
          ? const BenchApp(
              title: 'CRM Benchmark · Provider',
              counter: CounterSelector(),
              search: SearchSelector(),
              list: ListSelector(),
            )
          : const BenchApp(
              title: 'CRM Benchmark · Provider',
              counter: CounterConsumer(),
              search: SearchConsumer(),
              list: ListConsumer(),
            ),
    );
  }
}
