import 'dart:math';

import '../config.dart';
import '../model/customer.dart';

class MockData {
  MockData._();

  /// 100 pelanggan deterministik (`Random(42)`).
  static List<Customer> customers() {
    final rng = Random(BenchConfig.seed);
    const statuses = CustomerStatus.values;
    return List.generate(
      BenchConfig.customerCount,
      (i) => Customer(
        id: i,
        name: 'Pelanggan ${i + 1}',
        company: 'PT Contoh ${i % 20 + 1}',
        status: statuses[rng.nextInt(statuses.length)],
      ),
      growable: false,
    );
  }
}
