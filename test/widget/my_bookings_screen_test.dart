import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bobp/features/auth/data/auth_repository.dart';
import 'package:bobp/features/bookings/data/bookings_repository.dart';
import 'package:bobp/features/bookings/domain/appointment.dart';
import 'package:bobp/features/bookings/presentation/my_bookings_screen.dart';

class MockBookingsRepository extends Mock implements BookingsRepository {}

Appointment _appt(AppointmentStatus status, DateTime start) => Appointment(
  id: 'a1',
  businessId: 'b1',
  serviceName: 'Haircut',
  priceCents: 25000,
  durationMinutes: 60,
  startAt: start,
  endAt: start.add(const Duration(hours: 1)),
  status: status,
  businessName: 'Test Salon',
);

Future<void> _pump(WidgetTester tester, MockBookingsRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authUserIdProvider.overrideWith((ref) => Stream.value('user-1')),
        bookingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late MockBookingsRepository repo;

  setUp(() => repo = MockBookingsRepository());

  testWidgets('shows the empty state', (tester) async {
    when(() => repo.myBookings()).thenAnswer((_) async => []);
    await _pump(tester, repo);
    expect(find.text('No bookings yet.'), findsOneWidget);
  });

  testWidgets('upcoming pending booking can be cancelled', (tester) async {
    when(() => repo.myBookings()).thenAnswer((_) async => [
      _appt(AppointmentStatus.pending,
          DateTime.now().add(const Duration(days: 1))),
    ]);
    await _pump(tester, repo);

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Test Salon'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('past or cancelled bookings have no cancel action', (tester) async {
    when(() => repo.myBookings()).thenAnswer((_) async => [
      _appt(AppointmentStatus.cancelled,
          DateTime.now().add(const Duration(days: 1))),
    ]);
    await _pump(tester, repo);

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
