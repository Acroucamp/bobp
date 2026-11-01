import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/bookings_repository.dart';
import '../domain/appointment.dart';
import '../domain/appointment_filter.dart';

/// Owner/staff view: manage appointments for one business, with filters.
class BusinessAppointmentsScreen extends ConsumerStatefulWidget {
  const BusinessAppointmentsScreen({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<BusinessAppointmentsScreen> createState() =>
      _BusinessAppointmentsScreenState();
}

class _BusinessAppointmentsScreenState
    extends ConsumerState<BusinessAppointmentsScreen> {
  AppointmentFilter _filter = const AppointmentFilter();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _set(Appointment a, AppointmentStatus status) async {
    try {
      await ref.read(bookingsRepositoryProvider).setStatus(a.id, status);
      ref.invalidate(businessAppointmentsProvider(widget.businessId));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filter.hasRange
          ? DateTimeRange(start: _filter.from!, end: _filter.to!)
          : null,
    );
    if (picked != null) {
      setState(() => _filter = _filter.copyWith(
        from: DateTime(picked.start.year, picked.start.month, picked.start.day),
        to: DateTime(picked.end.year, picked.end.month, picked.end.day),
      ));
    }
  }

  List<Widget> _actions(Appointment a) {
    Widget btn(String label, AppointmentStatus s, {bool filled = false}) {
      void onPressed() => _set(a, s);
      return filled
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : TextButton(onPressed: onPressed, child: Text(label));
    }

    return switch (a.status) {
      AppointmentStatus.pending => [
        btn('Decline', AppointmentStatus.cancelled),
        btn('Confirm', AppointmentStatus.confirmed, filled: true),
      ],
      AppointmentStatus.confirmed => [
        btn('Cancel', AppointmentStatus.cancelled),
        btn('Complete', AppointmentStatus.completed, filled: true),
      ],
      _ => const [],
    };
  }

  Widget _filters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
            decoration: InputDecoration(
              hintText: 'Search customer or service',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  setState(() => _filter = _filter.copyWith(query: ''));
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _filter.status == null,
                    onSelected: (_) => setState(
                            () => _filter = _filter.copyWith(clearStatus: true)),
                  ),
                ),
                for (final s in AppointmentStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _filter.status == s,
                      onSelected: (_) =>
                          setState(() => _filter = _filter.copyWith(status: s)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(_filter.hasRange
                    ? '${Fmt.date(_filter.from!)} – ${Fmt.date(_filter.to!)}'
                    : 'Any date'),
              ),
              if (_filter.hasRange)
                IconButton(
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(
                          () => _filter = _filter.copyWith(clearRange: true)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appts = ref.watch(businessAppointmentsProvider(widget.businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: Column(
        children: [
          _filters(context),
          Expanded(
            child: appts.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is AppException ? e.message : 'Could not load appointments.',
                onRetry: () =>
                    ref.invalidate(businessAppointmentsProvider(widget.businessId)),
              ),
              data: (all) {
                final list = _filter.apply(all);
                if (all.isEmpty) {
                  return const EmptyView(
                      icon: Icons.event_note_outlined,
                      message: 'No appointments yet.');
                }
                if (list.isEmpty) {
                  return const EmptyView(
                      icon: Icons.filter_alt_off_outlined,
                      message: 'No appointments match your filters.');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref
                      .refresh(businessAppointmentsProvider(widget.businessId).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final actions = _actions(a);
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
                              Text(a.customerName?.isNotEmpty == true
                                  ? a.customerName!
                                  : 'Former customer'),
                              Text(Fmt.dateTime(a.startAt)),
                              Text('${Money.format(a.priceCents)} · ${a.durationMinutes} min'),
                              if (actions.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OverflowBar(spacing: 8, children: actions),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
