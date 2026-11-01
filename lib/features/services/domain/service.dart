class Service {
  const Service({
    required this.id,
    required this.businessId,
    required this.name,
    required this.priceCents,
    required this.durationMinutes,
    required this.isActive,
  });

  final String id;
  final String businessId;
  final String name;
  final int priceCents;
  final int durationMinutes;
  final bool isActive;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'] as String,
    businessId: j['business_id'] as String,
    name: j['name'] as String,
    priceCents: j['price_cents'] as int,
    durationMinutes: j['duration_minutes'] as int,
    isActive: j['is_active'] as bool,
  );
}
