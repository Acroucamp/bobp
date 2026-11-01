import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/features/bookings/domain/appointment.dart';
import 'package:bobp/features/bookings/domain/appointment_filter.dart';

Appointment _a(String id, String service, String? customer,
    AppointmentStatus status, DateTime start) {
  return Appointment(
    id: id,
    businessId: 'b',
    serviceName: service,
    priceCents: 10000,
    durationMinutes: 60,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    status: status,
    customerName: customer,
  );
}

void main() {
  final list = [
    _a('1', 'Haircut', 'Sam Smith', AppointmentStatus.pending, DateTime(2030, 1, 10, 9)),
    _a('2', 'Beard trim', 'Alex Jones', AppointmentStatus.confirmed, DateTime(2030, 1, 11, 10)),
    _a('3', 'Haircut', null, AppointmentStatus.cancelled, DateTime(2030, 1, 12, 11)),
  ];

  test('empty filter returns everything', () {
    expect(const AppointmentFilter().apply(list).length, 3);
    expect(const AppointmentFilter().isEmpty, isTrue);
  });

  test('filters by status', () {
    final f = const AppointmentFilter(status: AppointmentStatus.confirmed);
    expect(f.apply(list).map((a) => a.id), ['2']);
  });

  test('search matches service and customer, case-insensitive', () {
    expect(const AppointmentFilter(query: 'haircut').apply(list).length, 2);
    expect(const AppointmentFilter(query: 'ALEX').apply(list).map((a) => a.id), ['2']);
  });

  test('date range is inclusive on both ends', () {
    final f = AppointmentFilter(from: DateTime(2030, 1, 11), to: DateTime(2030, 1, 12));
    expect(f.apply(list).map((a) => a.id), ['2', '3']);
  });

  test('filters combine', () {
    final f = AppointmentFilter(
      status: AppointmentStatus.cancelled,
      query: 'haircut',
      from: DateTime(2030, 1, 1),
      to: DateTime(2030, 1, 31),
    );
    expect(f.apply(list).map((a) => a.id), ['3']);
  });

  test('copyWith can clear status and range', () {
    var f = AppointmentFilter(
      status: AppointmentStatus.pending,
      from: DateTime(2030, 1, 1),
      to: DateTime(2030, 1, 2),
    );
    f = f.copyWith(clearStatus: true, clearRange: true);
    expect(f.isEmpty, isTrue);
  });
}
