import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/crm_state_notifier.dart';

/// B-S: hanya bergantung pada `searchQuery`.
class SearchSelect extends ConsumerWidget {
  const SearchSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(crmProvider.select((s) => s.searchQuery));
    RebuildCounter.hit(RebuildCounter.searchField);
    return SearchFieldView(query: query);
  }
}
