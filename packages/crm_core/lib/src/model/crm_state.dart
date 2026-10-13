import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import 'customer.dart';

/// *State* aplikasi CRM. *Immutable*: setiap pembaruan membuat objek baru
/// lewat [copyWith], termasuk *list* baru saat satu item berubah.
///
/// `==`/`hashCode` sengaja tidak di-override. Pola selektif membandingkan
/// bagian *state* dengan `==` bawaan tiap properti: `int` dan `String` per
/// nilai, `List` per identitas.
@immutable
class CrmState {
  const CrmState({
    required this.counter,
    required this.customers,
    required this.searchQuery,
  });

  factory CrmState.initial() =>
      CrmState(counter: 0, customers: MockData.customers(), searchQuery: '');

  final int counter;
  final List<Customer> customers;
  final String searchQuery;

  CrmState copyWith({
    int? counter,
    List<Customer>? customers,
    String? searchQuery,
  }) =>
      CrmState(
        counter: counter ?? this.counter,
        customers: customers ?? this.customers,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  // Transisi *state* yang dipakai kedua aplikasi, agar cara membuat objek
  // baru identik dan hanya mekanisme notifikasinya yang berbeda.

  CrmState incremented() => copyWith(counter: counter + 1);

  /// *List* baru dengan item ke-[index] diganti; *list* lama tidak disentuh.
  CrmState withCustomerAt(int index, Customer customer) {
    final list = List<Customer>.of(customers, growable: false);
    list[index] = customer;
    return copyWith(customers: list);
  }

  CrmState withSearchQuery(String query) => copyWith(searchQuery: query);
}
