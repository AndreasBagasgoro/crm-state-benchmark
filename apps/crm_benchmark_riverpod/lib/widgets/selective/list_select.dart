import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/crm_state_notifier.dart';

/// B-S: hanya bergantung pada `customers` (dibandingkan dengan `==`, yaitu identitas `List`).
class ListSelect extends ConsumerWidget {
  const ListSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(crmProvider.select((s) => s.customers));
    RebuildCounter.hit(RebuildCounter.customerList);
    return CustomerListView(customers: customers);
  }
}
