import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/presentation/home_shell.dart';
import '../../services/data/services_repository.dart';
import '../data/bookings_repository.dart';

class BookSlotScreen extends ConsumerStatefulWidget {
  const BookSlotScreen({super.key, required this.businessId, required this.serviceId});
  final String businessId;
  final String serviceId;

  @override
  ConsumerState<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends ConsumerState<BookSlotScreen> {
  late DateTime _day = _today();
  DateTime? _selected;
  bool _booking = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  SlotQuery get _query =>
      (businessId: widget.businessId, serviceId: widget.serviceId, day: _day);

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today(),
      lastDate: _today().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _day = DateTime(picked.year, picked.month, picked.day);
        _selected = null;
      });
    }
  }

  Future<void> _confirm() async {
    final slot = _selected;
    if (slot == null) return;
    final router = GoRouter.of(context);
    setState(() => _booking = true);
    try {
      await ref.read(bookingsRepositoryProvider).book(
        businessId: widget.businessId,
        serviceId: widget.serviceId,
        startAt: slot,
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking requested. Waiting for confirmation.')),
      );
      // Back to the home tabs, on "My bookings" (tab 1 for customers).
      ref.read(homeTabProvider.notifier).select(1);
      router.go(AppRoutes.home);
    } on AppException catch (e) {
      // most likely someone else took the slot: refresh the list
      ref.invalidate(availableSlotsProvider(_query));
      if (mounted) {
        setState(() => _selected = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref
        .watch(servicesProvider(widget.businessId))
        .value
        ?.where((s) => s.id == widget.serviceId)
        .firstOrNull;
    final slots = ref.watch(availableSlotsProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Pick a time')),
      body: Column(
        children: [
          if (service != null)
            ListTile(
              title: Text(service.name),
              subtitle: Text(
                  '${Money.format(service.priceCents)} · ${service.durationMinutes} min'),
            ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(Fmt.date(_day)),
            trailing: TextButton(onPressed: _pickDay, child: const Text('Change')),
          ),
          const Divider(height: 1),
          Expanded(
            child: slots.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is AppException ? e.message : 'Could not load times.',
                onRetry: () => ref.invalidate(availableSlotsProvider(_query)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyView(
                  icon: Icons.event_busy_outlined,
                  message: 'No times available on this day.')
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in list)
                      ChoiceChip(
                        label: Text(Fmt.time(s)),
                        selected: _selected == s,
                        onSelected: (_) => setState(() => _selected = s),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: (_selected == null || _booking) ? null : _confirm,
              child: _booking
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_selected == null
                  ? 'Select a time'
                  : 'Request ${Fmt.time(_selected!)}'),
            ),
          ),
        ],
      ),
    );
  }
}
