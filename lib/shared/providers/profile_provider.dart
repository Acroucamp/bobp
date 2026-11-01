import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/guard.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/profile.dart';
import 'supabase_provider.dart';

/// The signed-in user's profile (null while signed out).
final profileProvider = FutureProvider<Profile?>((ref) async {
  final uid = await ref.watch(authUserIdProvider.future);
  if (uid == null) return null;
  final client = ref.watch(supabaseClientProvider);
  return guardRequest(() async {
    final row = await client
        .from('profiles')
        .select('id, full_name, email, account_type')
        .eq('id', uid)
        .single();
    return Profile.fromJson(row);
  });
});
