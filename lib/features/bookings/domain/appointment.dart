enum AppointmentStatus {
  pending,
  confirmed,
  cancelled,
  completed;

  static AppointmentStatus parse(String s) => values.byName(s);

  String get label => name[0].toUpperCase() + name.substring(1);

  /// Still occupies a time slot.
  bool get isActive => this == pending || this == confirmed;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.businessId,
    required this.serviceName,
    required this.priceCents,
    required this.durationMinutes,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.businessName,
    this.customerName,
  });

  final String id;
  final String businessId;
  final String serviceName;
  final int priceCents;
  final int durationMinutes;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;
  final String? businessName;
  final String? customerName;

  bool get isUpcoming => endAt.isAfter(DateTime.now());

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'] as String,
    businessId: j['business_id'] as String,
    serviceName: j['service_name'] as String,
    priceCents: j['price_cents'] as int,
    durationMinutes: j['duration_minutes'] as int,
    startAt: DateTime.parse(j['start_at'] as String),
    endAt: DateTime.parse(j['end_at'] as String),
    status: AppointmentStatus.parse(j['status'] as String),
    businessName: (j['businesses'] as Map<String, dynamic>?)?['name'] as String?,
    customerName: (j['customer'] as Map<String, dynamic>?)?['full_name'] as String?,
  );
}
