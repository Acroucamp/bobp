import 'appointment.dart';

/// Client-side filter for the owner's appointment list.
/// [from] and [to] are calendar days (inclusive).
class AppointmentFilter {
  const AppointmentFilter({this.status, this.from, this.to, this.query = ''});

  final AppointmentStatus? status;
  final DateTime? from;
  final DateTime? to;
  final String query;

  bool get hasRange => from != null && to != null;
  bool get isEmpty =>
      status == null && from == null && to == null && query.trim().isEmpty;

  AppointmentFilter copyWith({
    AppointmentStatus? status,
    bool clearStatus = false,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    String? query,
  }) =>
      AppointmentFilter(
        status: clearStatus ? null : (status ?? this.status),
        from: clearRange ? null : (from ?? this.from),
        to: clearRange ? null : (to ?? this.to),
        query: query ?? this.query,
      );

  List<Appointment> apply(List<Appointment> all) {
    final q = query.trim().toLowerCase();
    return all.where((a) {
      if (status != null && a.status != status) return false;

      final local = a.startAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (from != null && day.isBefore(from!)) return false;
      if (to != null && day.isAfter(to!)) return false;

      if (q.isNotEmpty) {
        final hay = '${a.serviceName} ${a.customerName ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }
}
