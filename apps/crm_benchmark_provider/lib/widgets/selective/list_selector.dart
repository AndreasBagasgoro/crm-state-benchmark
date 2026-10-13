import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/crm_state_provider.dart';

/// A-S: hanya bergantung pada `customers`.
///
/// Keputusan K2 (opsi a): `shouldRebuild` dibiarkan *default*, yaitu
/// `DeepCollectionEquality` bawaan Provider.
class ListSelector extends StatelessWidget {
  const ListSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<CrmStateProvider, List<Customer>>(
      selector: (_, p) => p.state.customers,
      builder: (_, customers, __) {
        RebuildCounter.hit(RebuildCounter.customerList);
        return CustomerListView(customers: customers);
      },
    );
  }
}
