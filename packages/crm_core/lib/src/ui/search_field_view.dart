import 'package:flutter/material.dart';

/// Kolom pencarian yang menampilkan [query] dari *state*. `readOnly` karena
/// nilainya berasal dari *state*, bukan dari ketikan pengguna.
class SearchFieldView extends StatefulWidget {
  const SearchFieldView({super.key, required this.query});

  final String query;

  @override
  State<SearchFieldView> createState() => _SearchFieldViewState();
}

class _SearchFieldViewState extends State<SearchFieldView> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(SearchFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: true,
      enableInteractiveSelection: false,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: 'Cari pelanggan',
        border: OutlineInputBorder(),
      ),
    );
  }
}
