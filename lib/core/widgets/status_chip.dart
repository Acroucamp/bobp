import 'package:flutter/material.dart';

import '../../features/bookings/domain/appointment.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      AppointmentStatus.pending => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AppointmentStatus.confirmed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AppointmentStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      AppointmentStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}
