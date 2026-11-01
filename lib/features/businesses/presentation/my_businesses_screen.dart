import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../data/business_repository.dart';

/// Provider home: your businesses and shortcuts to manage them.
class MyBusinessesScreen extends ConsumerWidget {
  const MyBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(myBusinessesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My business')),
      body: memberships.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load your businesses.',
          onRetry: () => ref.invalidate(myBusinessesProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.refresh(myBusinessesProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (list.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set up your business',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text(
                            'Create your business, add your services and start '
                                'taking bookings.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.push(AppRoutes.newBusiness),
                          child: const Text('Create your business'),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final m in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.business.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(m.isOwner ? 'Owner' : 'Staff'),
                        OverflowBar(
                          alignment: MainAxisAlignment.start,
                          children: [
                            if (m.isOwner)
                              TextButton(
                                onPressed: () => context
                                    .push(AppRoutes.dashboard(m.business.id)),
                                child: const Text('Dashboard'),
                              ),
                            TextButton(
                              onPressed: () => context
                                  .push(AppRoutes.appointments(m.business.id)),
                              child: const Text('Appointments'),
                            ),
                            TextButton(
                              onPressed: () => context
                                  .push(AppRoutes.services(m.business.id)),
                              child: const Text('Services'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (list.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.newBusiness),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another business'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
