import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../bookings/data/bookings_repository.dart';
import '../data/stats_repository.dart';
import '../domain/business_stats.dart';

enum _Period { week, month, thisMonth, custom }

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  const BusinessDashboardScreen({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState
    extends ConsumerState<BusinessDashboardScreen> {
  _Period _period = _Period.week;
  DateTimeRange? _custom;

  (DateTime, DateTime) get _range {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    switch (_period) {
      case _Period.week:
        return (today.subtract(const Duration(days: 6)), today);
      case _Period.month:
        return (today.subtract(const Duration(days: 29)), today);
      case _Period.thisMonth:
        return (DateTime(n.year, n.month, 1), today);
      case _Period.custom:
        final c = _custom;
        return c == null ? (today.subtract(const Duration(days: 6)), today) : (c.start, c.end);
    }
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom,
    );
    if (picked != null) {
      setState(() {
        _custom = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _period = _Period.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _range;
    final query = (businessId: widget.businessId, from: from, to: to);
    final stats = ref.watch(businessStatsProvider(query));
    final appts = ref.watch(businessAppointmentsProvider(widget.businessId));

    final now = DateTime.now();
    final today = appts.value
        ?.where((a) {
      final l = a.startAt.toLocal();
      return l.year == now.year &&
          l.month == now.month &&
          l.day == now.day &&
          a.status.isActive;
    })
        .toList() ??
        const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(businessAppointmentsProvider(widget.businessId));
          await ref.refresh(businessStatsProvider(query).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('7 days'),
                  selected: _period == _Period.week,
                  onSelected: (_) => setState(() => _period = _Period.week),
                ),
                ChoiceChip(
                  label: const Text('30 days'),
                  selected: _period == _Period.month,
                  onSelected: (_) => setState(() => _period = _Period.month),
                ),
                ChoiceChip(
                  label: const Text('This month'),
                  selected: _period == _Period.thisMonth,
                  onSelected: (_) => setState(() => _period = _Period.thisMonth),
                ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _period == _Period.custom,
                  onSelected: (_) => _pickCustom(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${Fmt.date(from)} – ${Fmt.date(to)}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            stats.when(
              loading: () => const SizedBox(height: 240, child: LoadingView()),
              error: (e, _) => SizedBox(
                height: 240,
                child: ErrorView(
                  message: e is AppException ? e.message : 'Could not load statistics.',
                  onRetry: () => ref.invalidate(businessStatsProvider(query)),
                ),
              ),
              data: (s) => _StatsBody(stats: s),
            ),
            const SizedBox(height: 16),
            Text("Today's appointments",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (today.isEmpty)
              const Text('Nothing scheduled for today.')
            else
              for (final a in today)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(Fmt.time(a.startAt),
                      style: Theme.of(context).textTheme.titleMedium),
                  title: Text(a.serviceName),
                  subtitle: Text(a.customerName?.isNotEmpty == true
                      ? a.customerName!
                      : 'Former customer'),
                  trailing: Text(a.status.label),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.appointments(widget.businessId)),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('All appointments'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final BusinessStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _Kpi('Revenue', Money.format(stats.revenueCents)),
            _Kpi('Bookings', '${stats.total}'),
            _Kpi('Pending', '${stats.pending}'),
            _Kpi('Completed', '${stats.completed}'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Revenue per day (completed bookings)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (stats.revenueCents == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No completed bookings in this period.')),
          )
        else
          SizedBox(height: 220, child: _RevenueChart(daily: stats.daily)),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.daily});
  final List<DailyStat> daily;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final step = (daily.length / 7).ceil().clamp(1, 100);
    final barWidth = daily.length > 20 ? 4.0 : 10.0;

    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < daily.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: daily[i].revenueCents / 100,
                  width: barWidth,
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Text(
                'R${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= daily.length || i % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${daily[i].day.day}',
                      style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
