import 'package:flutter/material.dart';

/// Susunan halaman dashboard: [counter], [search], lalu [list] yang mengisi
/// sisa layar. Identik di kedua aplikasi.
class DashboardLayout extends StatelessWidget {
  const DashboardLayout({
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: counter,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: search,
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}
