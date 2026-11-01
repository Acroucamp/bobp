import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/state_views.dart';
import '../../businesses/data/business_repository.dart';
import '../data/services_repository.dart';
import '../domain/service.dart';
import 'service_form_sheet.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key, required this.businessId});
  final String businessId;

  Future<void> _toggle(BuildContext context, WidgetRef ref, Service s, bool v) async {
    try {
      await ref.read(servicesRepositoryProvider).setActive(s.id, v);
      ref.invalidate(servicesProvider(businessId));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider(businessId));
    final canEdit = ref.watch(myBusinessesProvider).value?.any(
          (m) => m.business.id == businessId && m.isOwner,
    ) ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
        onPressed: () =>
            showServiceFormSheet(context, businessId: businessId),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      )
          : null,
      body: services.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load services.',
          onRetry: () => ref.invalidate(servicesProvider(businessId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.content_cut,
              message: canEdit
                  ? 'No services yet. Add your first one.'
                  : 'No services yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(servicesProvider(businessId).future),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = list[i];
                return ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    '${Money.format(s.priceCents)} · ${s.durationMinutes} min'
                        '${s.isActive ? '' : ' · Hidden from customers'}',
                  ),
                  trailing: canEdit
                      ? Switch(
                    value: s.isActive,
                    onChanged: (v) => _toggle(context, ref, s, v),
                  )
                      : null,
                  onTap: canEdit
                      ? () => showServiceFormSheet(context,
                      businessId: businessId, service: s)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
