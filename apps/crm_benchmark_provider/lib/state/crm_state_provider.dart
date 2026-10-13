import 'package:crm_core/crm_core.dart';
import 'package:flutter/foundation.dart';

/// Versi A: `ChangeNotifier` yang memegang [CrmState] *immutable*.
class CrmStateProvider extends ChangeNotifier implements CrmActions {
  CrmState _state = CrmState.initial();

  CrmState get state => _state;

  @override
  CrmState get current => _state;

  @override
  void incrementCounter() {
    _state = _state.incremented();
    notifyListeners();
  }

  @override
  void updateCustomer(int index, Customer updated) {
    _state = _state.withCustomerAt(index, updated);
    notifyListeners();
  }

  @override
  void updateSearchQuery(String query) {
    _state = _state.withSearchQuery(query);
    notifyListeners();
  }
}
