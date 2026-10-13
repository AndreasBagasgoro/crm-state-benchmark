import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/crm_state_provider.dart';

/// A-S: hanya bergantung pada `searchQuery`.
class SearchSelector extends StatelessWidget {
  const SearchSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<CrmStateProvider, String>(
      selector: (_, p) => p.state.searchQuery,
      builder: (_, query, __) {
        RebuildCounter.hit(RebuildCounter.searchField);
        return SearchFieldView(query: query);
      },
    );
  }
}
