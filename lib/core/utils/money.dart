/// Money is stored as integer cents (ZAR). Never use doubles for amounts.
class Money {
  static String format(int cents) {
    final rands = cents ~/ 100;
    final rest = (cents % 100).toString().padLeft(2, '0');
    return 'R$rands.$rest';
  }

  /// "250", "250.5", "250,50" -> cents. Returns null if invalid.
  static int? parseToCents(String input) {
    final s = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final rands = int.parse(parts[0]);
    final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return rands * 100 + cents;
  }
}
