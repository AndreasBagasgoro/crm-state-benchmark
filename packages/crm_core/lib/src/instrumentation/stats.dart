import 'dart:math';

/// Statistik ringkas untuk sampel numerik.
class Stats {
  Stats._();

  static double mean(List<num> xs) =>
      xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

  /// Persentil dengan interpolasi linear (sama dengan `numpy.percentile`
  /// *default*). [p] dalam rentang 0–100.
  static double percentile(List<num> xs, double p) {
    if (xs.isEmpty) return 0;
    final sorted = xs.map((x) => x.toDouble()).toList()..sort();
    final rank = (p / 100) * (sorted.length - 1);
    final lo = rank.floor();
    final hi = min(lo + 1, sorted.length - 1);
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
  }

  static double median(List<num> xs) => percentile(xs, 50);

  static double round(double x, [int digits = 3]) {
    final f = pow(10, digits);
    return (x * f).round() / f;
  }
}
