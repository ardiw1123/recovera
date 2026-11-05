final RegExp _thousands = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

/// Formats counts with thousand separators, e.g. `1240` -> `1,240`.
String formatCount(int value) {
  if (value < 0) return '-${formatCount(-value)}';
  return value.toString().replaceAllMapped(_thousands, (Match m) => '${m[1]},');
}
