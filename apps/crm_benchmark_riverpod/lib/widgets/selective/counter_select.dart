import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/crm_state_notifier.dart';

/// B-S: hanya bergantung pada `counter`.
class CounterSelect extends ConsumerWidget {
  const CounterSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(crmProvider.select((s) => s.counter));
    RebuildCounter.hit(RebuildCounter.counterDisplay);
    return CounterView(count: counter);
  }
}
