import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/guard.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/appointment.dart';

class BookingsRepository {
  BookingsRepository(this._client);
  final SupabaseClient _client;

  Future<List<DateTime>> availableSlots({
    required String businessId,
    required String serviceId,
    required DateTime day,
  }) =>
      guardRequest(() async {
        final rows = await _client.rpc('get_available_slots', params: {
          'p_business_id': businessId,
          'p_service_id': serviceId,
          'p_day': Fmt.isoDay(day),
        }) as List<dynamic>;
        return rows
            .map((r) => DateTime.parse((r as Map)['slot_start'] as String))
            .toList();
      });

  /// Books atomically on the server; the server picks a free provider.
  Future<void> book({
    required String businessId,
    required String serviceId,
    required DateTime startAt,
  }) =>
      guardRequest(() async {
        await _client.rpc('book_appointment', params: {
          'p_business_id': businessId,
          'p_service_id': serviceId,
          'p_start_at': startAt.toUtc().toIso8601String(),
        });
      });

  Future<List<Appointment>> myBookings() => guardRequest(() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppException('You are not signed in.');
    final rows = await _client
        .from('appointments')
        .select('*, businesses(name)')
        .eq('customer_id', uid)
        .order('start_at', ascending: false);
    return rows.map(Appointment.fromJson).toList();
  });

  Future<List<Appointment>> forBusiness(String businessId) =>
      guardRequest(() async {
        final rows = await _client
            .from('appointments')
            .select('*, customer:profiles!customer_id(full_name)')
            .eq('business_id', businessId)
            .order('start_at');
        return rows.map(Appointment.fromJson).toList();
      });

  /// The database enforces who may make which status change.
  Future<void> setStatus(String id, AppointmentStatus status) =>
      guardRequest(() async {
        await _client
            .from('appointments')
            .update({'status': status.name}).eq('id', id);
      });
}

final bookingsRepositoryProvider = Provider<BookingsRepository>(
      (ref) => BookingsRepository(ref.watch(supabaseClientProvider)),
);

typedef SlotQuery = ({String businessId, String serviceId, DateTime day});

final availableSlotsProvider =
FutureProvider.autoDispose.family<List<DateTime>, SlotQuery>((ref, q) {
  return ref.watch(bookingsRepositoryProvider).availableSlots(
    businessId: q.businessId,
    serviceId: q.serviceId,
    day: q.day,
  );
});

final myBookingsProvider = FutureProvider<List<Appointment>>((ref) async {
  final uid = await ref.watch(authUserIdProvider.future);
  if (uid == null) return [];
  return ref.watch(bookingsRepositoryProvider).myBookings();
});

final businessAppointmentsProvider =
FutureProvider.autoDispose.family<List<Appointment>, String>((ref, id) {
  return ref.watch(bookingsRepositoryProvider).forBusiness(id);
});
