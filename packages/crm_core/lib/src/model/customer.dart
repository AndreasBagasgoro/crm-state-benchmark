import 'package:flutter/foundation.dart';

enum CustomerStatus {
  prospek('Prospek'),
  aktif('Aktif'),
  nonaktif('Nonaktif');

  const CustomerStatus(this.label);
  final String label;

  /// Status berikutnya secara melingkar. Selalu berbeda dari status sekarang,
  /// sehingga setiap pembaruan item benar-benar mengubah nilai.
  CustomerStatus get next => values[(index + 1) % values.length];
}

/// Data satu pelanggan. *Immutable*; `==`/`hashCode` sengaja tidak di-override
/// (perbandingan memakai identitas objek).
@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.company,
    required this.status,
  });

  final int id;
  final String name;
  final String company;
  final CustomerStatus status;

  Customer copyWith({String? name, String? company, CustomerStatus? status}) =>
      Customer(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        status: status ?? this.status,
      );
}
