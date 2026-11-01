import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/features/dashboard/domain/business_stats.dart';

void main() {
  test('BusinessStats.fromJson parses totals and daily rows', () {
    final s = BusinessStats.fromJson({
      'total': 5,
      'pending': 1,
      'confirmed': 1,
      'completed': 2,
      'cancelled': 1,
      'revenue_cents': 50000,
      'daily': [
        {'day': '2030-01-10', 'bookings': 2, 'revenue_cents': 25000},
        {'day': '2030-01-11', 'bookings': 0, 'revenue_cents': 0},
      ],
    });
    expect(s.total, 5);
    expect(s.revenueCents, 50000);
    expect(s.daily.length, 2);
    expect(s.daily.first.day, DateTime(2030, 1, 10));
    expect(s.daily.first.revenueCents, 25000);
  });
}
