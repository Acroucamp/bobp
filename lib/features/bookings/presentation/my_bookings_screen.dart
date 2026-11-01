import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/bookings_repository.dart';
import '../domain/appointment.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text('${a.serviceName} on ${Fmt.dateTime(a.startAt)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .setStatus(a.id, AppointmentStatus.cancelled);
      ref.invalidate(myBookingsProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load bookings.',
          onRetry: () => ref.invalidate(myBookingsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyView(
            icon: Icons.event_note_outlined, message: 'No bookings yet.')
            : RefreshIndicator(
          onRefresh: () async => ref.refresh(myBookingsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              final canCancel = a.status.isActive && a.isUpcoming;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(a.serviceName,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          StatusChip(a.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (a.businessName != null) Text(a.businessName!),
                      Text(Fmt.dateTime(a.startAt)),
                      Text('${Money.format(a.priceCents)} · ${a.durationMinutes} min'),
                      if (canCancel)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancel(context, ref, a),
                            child: const Text('Cancel'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
