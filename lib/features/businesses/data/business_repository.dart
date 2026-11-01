import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/guard.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/business.dart';

class BusinessRepository {
  BusinessRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('You are not signed in.');
    return id;
  }

  /// Businesses the current user owns or works for.
  Future<List<BusinessMembership>> myMemberships() => guardRequest(() async {
    final rows = await _client
        .from('business_members')
        .select('role, businesses(id, name, description, owner_id)')
        .eq('user_id', _uid);
    return rows
        .map((r) => BusinessMembership(
      role: r['role'] as String,
      business: Business.fromJson(
          r['businesses'] as Map<String, dynamic>),
    ))
        .toList();
  });

  /// Every business customers can book with.
  Future<List<Business>> browse() => guardRequest(() async {
    final rows = await _client
        .from('businesses')
        .select('id, name, description, owner_id')
        .order('name');
    return rows.map(Business.fromJson).toList();
  });

  /// The database trigger makes the creator an 'owner' member automatically.
  Future<Business> create({required String name, String? description}) =>
      guardRequest(() async {
        final desc = description?.trim();
        final row = await _client
            .from('businesses')
            .insert({
          'name': name.trim(),
          'description': (desc == null || desc.isEmpty) ? null : desc,
          'owner_id': _uid,
        })
            .select()
            .single();
        return Business.fromJson(row);
      });
}

final businessRepositoryProvider = Provider<BusinessRepository>(
      (ref) => BusinessRepository(ref.watch(supabaseClientProvider)),
);

final myBusinessesProvider =
FutureProvider<List<BusinessMembership>>((ref) async {
  final uid = await ref.watch(authUserIdProvider.future);
  if (uid == null) return [];
  return ref.watch(businessRepositoryProvider).myMemberships();
});

final browseBusinessesProvider =
FutureProvider.autoDispose<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).browse();
});