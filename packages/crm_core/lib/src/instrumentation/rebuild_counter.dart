/// Penghitung pemanggilan *build* per *widget* konsumen.
///
/// Nama utama: `CounterDisplay`, `CustomerList`, `SearchField`.
/// Nama pendukung: `CustomerTile`.
class RebuildCounter {
  RebuildCounter._();

  static const counterDisplay = 'CounterDisplay';
  static const customerList = 'CustomerList';
  static const searchField = 'SearchField';
  static const customerTile = 'CustomerTile';

  static const mainWidgets = [counterDisplay, customerList, searchField];

  static bool recording = false;
  static final Map<String, int> counts = {};

  static void hit(String name) {
    if (!recording) return;
    counts[name] = (counts[name] ?? 0) + 1;
  }

  static int of(String name) => counts[name] ?? 0;

  static void reset() => counts.clear();
}
