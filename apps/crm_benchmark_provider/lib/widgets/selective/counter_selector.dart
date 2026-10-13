import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/crm_state_provider.dart';

/// A-S: hanya bergantung pada `counter`.
class CounterSelector extends StatelessWidget {
  const CounterSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<CrmStateProvider, int>(
      selector: (_, p) => p.state.counter,
      builder: (_, counter, __) {
        RebuildCounter.hit(RebuildCounter.counterDisplay);
        return CounterView(count: counter);
      },
    );
  }
}
