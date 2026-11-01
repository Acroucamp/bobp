import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../domain/business_stats.dart';

class StatsRepository {
  StatsRepository(this._client);
  final SupabaseClient _client;

  Future<BusinessStats> fetch({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) =>
      guardRequest(() async {
        final res = await _client.rpc('get_business_stats', params: {
          'p_business_id': businessId,
          'p_from': Fmt.isoDay(from),
          'p_to': Fmt.isoDay(to),
        });
        return BusinessStats.fromJson(Map<String, dynamic>.from(res as Map));
      });
}

final statsRepositoryProvider = Provider<StatsRepository>(
      (ref) => StatsRepository(ref.watch(supabaseClientProvider)),
);

typedef StatsQuery = ({String businessId, DateTime from, DateTime to});

final businessStatsProvider =
FutureProvider.autoDispose.family<BusinessStats, StatsQuery>((ref, q) {
  return ref.watch(statsRepositoryProvider).fetch(
    businessId: q.businessId,
    from: q.from,
    to: q.to,
  );
});
