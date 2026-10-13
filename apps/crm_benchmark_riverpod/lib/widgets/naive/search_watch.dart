import 'package:crm_core/crm_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/crm_state_notifier.dart';

/// B-N: berlangganan seluruh `CrmState`.
class SearchWatch extends ConsumerWidget {
  const SearchWatch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(crmProvider);
    RebuildCounter.hit(RebuildCounter.searchField);
    return SearchFieldView(query: s.searchQuery);
  }
}
