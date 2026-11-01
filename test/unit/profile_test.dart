import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/shared/models/profile.dart';

void main() {
  test('AccountType.parse defaults to customer', () {
    expect(AccountType.parse('provider'), AccountType.provider);
    expect(AccountType.parse('customer'), AccountType.customer);
    expect(AccountType.parse(null), AccountType.customer);
    expect(AccountType.parse('admin'), AccountType.customer);
  });

  test('Profile.fromJson', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'full_name': 'Sam',
      'email': 'sam@example.com',
      'account_type': 'provider',
    });
    expect(p.isProvider, isTrue);
    expect(p.fullName, 'Sam');
  });
}
