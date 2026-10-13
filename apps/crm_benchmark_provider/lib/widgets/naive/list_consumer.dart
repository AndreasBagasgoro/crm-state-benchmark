import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/crm_state_provider.dart';

/// A-N: berlangganan seluruh `CrmStateProvider`.
class ListConsumer extends StatelessWidget {
  const ListConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CrmStateProvider>(
      builder: (_, p, __) {
        RebuildCounter.hit(RebuildCounter.customerList);
        return CustomerListView(customers: p.state.customers);
      },
    );
  }
}
