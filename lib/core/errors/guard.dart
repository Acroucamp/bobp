import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Runs a backend call and converts low-level errors into [AppException]s
/// with messages that are safe to show to users.
Future<T> guardRequest<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on PostgrestException catch (e) {
    throw AppException(switch (e.code) {
      '23514' => 'Some values are not allowed. Please check your input.',
      '23505' => 'That already exists.',
      '23P01' => 'That time slot is no longer available. Please pick another.',
      '22023' => 'That action is not allowed.',
      '42501' => 'You do not have permission to do that.',
      _ => 'Request failed. Please try again.',
    });
  } catch (_) {
    throw const AppException('Something went wrong. Please try again.');
  }
}
