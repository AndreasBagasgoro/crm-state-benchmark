import 'package:flutter/material.dart';

import '../instrumentation/rebuild_counter.dart';
import '../model/customer.dart';

class CustomerTile extends StatelessWidget {
  const CustomerTile({super.key, required this.customer});

  final Customer customer;

  static Color _statusColor(CustomerStatus s) => switch (s) {
        CustomerStatus.prospek => Colors.amber.shade200,
        CustomerStatus.aktif => Colors.green.shade200,
        CustomerStatus.nonaktif => Colors.grey.shade300,
      };

  @override
  Widget build(BuildContext context) {
    RebuildCounter.hit(RebuildCounter.customerTile);
    return ListTile(
      leading: CircleAvatar(child: Text('${customer.id + 1}')),
      title: Text(customer.name),
      subtitle: Text(customer.company),
      trailing: Chip(
        label: Text(customer.status.label),
        backgroundColor: _statusColor(customer.status),
        side: BorderSide.none,
      ),
    );
  }
}
