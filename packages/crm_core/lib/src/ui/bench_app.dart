import 'package:flutter/material.dart';

import 'dashboard_layout.dart';

/// `MaterialApp` yang sama untuk kedua aplikasi. Isi slot disediakan oleh
/// lapisan *state management* tiap aplikasi.
class BenchApp extends StatelessWidget {
  const BenchApp({
    super.key,
    required this.title,
    required this.counter,
    required this.search,
    required this.list,
  });

  final String title;
  final Widget counter;
  final Widget search;
  final Widget list;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: DashboardLayout(
        title: title,
        counter: counter,
        search: search,
        list: list,
      ),
    );
  }
}
