import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/crm_state_provider.dart';

/// A-N: berlangganan seluruh `CrmStateProvider`.
class SearchConsumer extends StatelessWidget {
  const SearchConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CrmStateProvider>(
      builder: (_, p, __) {
        RebuildCounter.hit(RebuildCounter.searchField);
        return SearchFieldView(query: p.state.searchQuery);
      },
    );
  }
}
