import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../businesses/data/business_repository.dart';
import '../../services/data/services_repository.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({super.key, required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref
        .watch(browseBusinessesProvider)
        .value
        ?.where((b) => b.id == businessId)
        .firstOrNull;
    final services = ref.watch(servicesProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: Text(business?.name ?? 'Choose a service')),
      body: services.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load services.',
          onRetry: () => ref.invalidate(servicesProvider(businessId)),
        ),
        data: (all) {
          final list = all.where((s) => s.isActive).toList();
          if (list.isEmpty) {
            return const EmptyView(
                icon: Icons.content_cut, message: 'No services available.');
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                title: Text(s.name),
                subtitle: Text('${Money.format(s.priceCents)} · ${s.durationMinutes} min'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.book(businessId, s.id)),
              );
            },
          );
        },
      ),
    );
  }
}
