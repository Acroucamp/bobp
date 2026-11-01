import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/features/bookings/domain/appointment.dart';
import 'package:bobp/core/utils/formatters.dart';

void main() {
  test('AppointmentStatus.parse and isActive', () {
    expect(AppointmentStatus.parse('pending'), AppointmentStatus.pending);
    expect(AppointmentStatus.pending.isActive, isTrue);
    expect(AppointmentStatus.confirmed.isActive, isTrue);
    expect(AppointmentStatus.cancelled.isActive, isFalse);
    expect(AppointmentStatus.completed.isActive, isFalse);
  });

  test('Appointment.fromJson reads joined names', () {
    final a = Appointment.fromJson({
      'id': '1',
      'business_id': 'b',
      'service_name': 'Haircut',
      'price_cents': 25000,
      'duration_minutes': 60,
      'start_at': '2030-01-01T08:00:00+00:00',
      'end_at': '2030-01-01T09:00:00+00:00',
      'status': 'confirmed',
      'businesses': {'name': 'Test Salon'},
      'customer': {'full_name': 'Sam'},
    });
    expect(a.businessName, 'Test Salon');
    expect(a.customerName, 'Sam');
    expect(a.status, AppointmentStatus.confirmed);
  });

  test('Fmt.isoDay pads month and day', () {
    expect(Fmt.isoDay(DateTime(2026, 3, 5)), '2026-03-05');
  });
}
