import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../businesses/data/business_repository.dart';

class BrowseBusinessesScreen extends ConsumerWidget {
  const BrowseBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(browseBusinessesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Book an appointment')),
      body: businesses.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load businesses.',
          onRetry: () => ref.invalidate(browseBusinessesProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyView(
            icon: Icons.storefront_outlined,
            message: 'No businesses available yet.')
            : RefreshIndicator(
          onRefresh: () async => ref.refresh(browseBusinessesProvider.future),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = list[i];
              return ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(b.name),
                subtitle: b.description == null
                    ? null
                    : Text(b.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.businessDetail(b.id)),
              );
            },
          ),
        ),
      ),
    );
  }
}
