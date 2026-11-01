import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../domain/service.dart';

/// Services are archived (is_active = false) rather than deleted, because
/// existing appointments reference them and keep a snapshot of their details.
class ServicesRepository {
  ServicesRepository(this._client);
  final SupabaseClient _client;

  Future<List<Service>> list(String businessId) => guardRequest(() async {
    final rows = await _client
        .from('services')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return rows.map(Service.fromJson).toList();
  });

  Future<void> create({
    required String businessId,
    required String name,
    required int priceCents,
    required int durationMinutes,
    required bool isActive,
  }) =>
      guardRequest(() async {
        await _client.from('services').insert({
          'business_id': businessId,
          'name': name.trim(),
          'price_cents': priceCents,
          'duration_minutes': durationMinutes,
          'is_active': isActive,
        });
      });

  Future<void> update({
    required String id,
    required String name,
    required int priceCents,
    required int durationMinutes,
    required bool isActive,
  }) =>
      guardRequest(() async {
        await _client.from('services').update({
          'name': name.trim(),
          'price_cents': priceCents,
          'duration_minutes': durationMinutes,
          'is_active': isActive,
        }).eq('id', id);
      });

  Future<void> setActive(String id, bool isActive) => guardRequest(() async {
    await _client.from('services').update({'is_active': isActive}).eq('id', id);
  });
}

final servicesRepositoryProvider = Provider<ServicesRepository>(
      (ref) => ServicesRepository(ref.watch(supabaseClientProvider)),
);

final servicesProvider =
FutureProvider.autoDispose.family<List<Service>, String>((ref, businessId) {
  return ref.watch(servicesRepositoryProvider).list(businessId);
});
