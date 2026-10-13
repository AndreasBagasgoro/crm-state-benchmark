import 'package:crm_core/crm_core.dart';
// Riverpod 3: StateNotifier/StateNotifierProvider adalah API legacy (K1 opsi a).
import 'package:flutter_riverpod/legacy.dart';

/// Versi B: `StateNotifier` yang memegang [CrmState] *immutable*.
class CrmStateNotifier extends StateNotifier<CrmState> implements CrmActions {
  CrmStateNotifier() : super(CrmState.initial());

  @override
  CrmState get current => state;

  @override
  void incrementCounter() => state = state.incremented();

  @override
  void updateCustomer(int index, Customer updated) =>
      state = state.withCustomerAt(index, updated);

  @override
  void updateSearchQuery(String query) => state = state.withSearchQuery(query);
}

final crmProvider = StateNotifierProvider<CrmStateNotifier, CrmState>(
  (ref) => CrmStateNotifier(),
);
