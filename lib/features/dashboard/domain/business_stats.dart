class DailyStat {
  const DailyStat({
    required this.day,
    required this.bookings,
    required this.revenueCents,
  });

  final DateTime day;
  final int bookings;
  final int revenueCents;
}

class BusinessStats {
  const BusinessStats({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.revenueCents,
    required this.daily,
  });

  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int revenueCents;
  final List<DailyStat> daily;

  factory BusinessStats.fromJson(Map<String, dynamic> j) => BusinessStats(
    total: (j['total'] as num).toInt(),
    pending: (j['pending'] as num).toInt(),
    confirmed: (j['confirmed'] as num).toInt(),
    completed: (j['completed'] as num).toInt(),
    cancelled: (j['cancelled'] as num).toInt(),
    revenueCents: (j['revenue_cents'] as num).toInt(),
    daily: [
      for (final d in (j['daily'] as List<dynamic>))
        DailyStat(
          day: DateTime.parse((d as Map<String, dynamic>)['day'] as String),
          bookings: (d['bookings'] as num).toInt(),
          revenueCents: (d['revenue_cents'] as num).toInt(),
        ),
    ],
  );
}
