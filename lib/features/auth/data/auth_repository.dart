import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/providers/supabase_provider.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  /// Deep link that email links (confirm signup, reset password) open.
  /// Must also be listed under Supabase > Authentication > URL Configuration.
  static const authRedirect = 'bobp://auth-callback';

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _client.auth
          .signInWithPassword(email: email.trim(), password: password));

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required AccountType accountType,
  }) =>
      _guard(() => _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: authRedirect,
        data: {
          'full_name': fullName.trim(),
          'account_type': accountType.name,
        },
      ));

  Future<void> resetPassword(String email) => _guard(() => _client.auth
      .resetPasswordForEmail(email.trim(), redirectTo: authRedirect));

  /// Used after the user opens the reset link (a recovery session is active).
  Future<void> updatePassword(String newPassword) => _guard(
          () => _client.auth.updateUser(UserAttributes(password: newPassword)));

  Future<void> signOut() => _guard(() => _client.auth.signOut());

  /// Permanently deletes the signed-in user via the `delete-account` Edge
  /// Function, then clears the local session.
  Future<void> deleteAccount() => _guard(() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut(scope: SignOutScope.local);
  });

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(e.message);
    } catch (_) {
      throw const AppException('Something went wrong. Please try again.');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Emits the signed-in user's id (or null). Data providers watch this so they
/// refetch when someone signs in/out instead of showing the previous user's data.
final authUserIdProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges.map((s) => s.session?.user.id);
});
