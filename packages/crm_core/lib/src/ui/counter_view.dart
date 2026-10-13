import 'package:flutter/material.dart';

/// Kartu "Pelanggan Aktif".
class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.people, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Pelanggan Aktif', style: theme.textTheme.titleMedium),
            ),
            Text('$count', style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
