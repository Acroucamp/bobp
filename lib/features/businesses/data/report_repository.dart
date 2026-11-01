import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/supabase_provider.dart';

class ReportRepository {
  ReportRepository(this._client);
  final SupabaseClient _client;

  Future<void> reportBusiness({
    required String businessId,
    required String category,
    String? details,
  }) async {
    final text = details?.trim();
    try {
      await _client.from('business_reports').insert({
        'business_id': businessId,
        'category': category,
        if (text != null && text.isNotEmpty) 'details': text,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppException('You have already reported this business. Thank you.');
      }
      throw const AppException('Could not send your report. Please try again.');
    } catch (_) {
      throw const AppException('Could not send your report. Please try again.');
    }
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
      (ref) => ReportRepository(ref.watch(supabaseClientProvider)),
);
