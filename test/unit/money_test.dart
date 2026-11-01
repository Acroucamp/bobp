import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/core/utils/money.dart';

void main() {
  group('Money.parseToCents', () {
    test('parses whole and decimal amounts', () {
      expect(Money.parseToCents('250'), 25000);
      expect(Money.parseToCents('250.5'), 25050);
      expect(Money.parseToCents('250,50'), 25050);
      expect(Money.parseToCents('0.05'), 5);
    });
    test('rejects invalid input', () {
      expect(Money.parseToCents(''), isNull);
      expect(Money.parseToCents('abc'), isNull);
      expect(Money.parseToCents('-5'), isNull);
      expect(Money.parseToCents('1.234'), isNull);
    });
  });

  test('Money.format', () {
    expect(Money.format(25000), 'R250.00');
    expect(Money.format(5), 'R0.05');
  });
}
