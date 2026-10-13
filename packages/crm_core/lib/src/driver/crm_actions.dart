import '../model/crm_state.dart';
import '../model/customer.dart';

/// Antarmuka aksi yang diimplementasikan lapisan *state management* tiap
/// aplikasi, sehingga *driver* tidak perlu tahu *library* mana yang dipakai.
abstract interface class CrmActions {
  void incrementCounter();
  void updateCustomer(int index, Customer updated);
  void updateSearchQuery(String query);
  CrmState get current;
}
