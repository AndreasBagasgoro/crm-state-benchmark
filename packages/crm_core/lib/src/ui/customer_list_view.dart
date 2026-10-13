import 'package:flutter/material.dart';

import '../model/customer.dart';
import 'customer_tile.dart';

class CustomerListView extends StatelessWidget {
  const CustomerListView({super.key, required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: customers.length,
      itemExtent: 72,
      itemBuilder: (_, i) => CustomerTile(customer: customers[i]),
    );
  }
}
