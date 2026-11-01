import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/data/auth_repository.dart';
import '../../bookings/presentation/browse_businesses_screen.dart';
import '../../bookings/presentation/my_bookings_screen.dart';
import '../../businesses/presentation/my_businesses_screen.dart';

/// Selected bottom-nav tab. Resets to the first tab when the user changes.
class HomeTab extends Notifier<int> {
  @override
  int build() {
    ref.watch(authUserIdProvider);
    return 0;
  }

  void select(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class _Tab {
  const _Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

const _customerTabs = [
  _Tab('Book', Icons.search, BrowseBusinessesScreen()),
  _Tab('My bookings', Icons.event_note_outlined, MyBookingsScreen()),
  _Tab('Account', Icons.person_outline, AccountScreen()),
];

const _providerTabs = [
  _Tab('My business', Icons.storefront_outlined, MyBusinessesScreen()),
  _Tab('Account', Icons.person_outline, AccountScreen()),
];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        body: ErrorView(
          message: e is AppException ? e.message : 'Could not load your profile.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
      data: (p) {
        if (p == null) return const Scaffold(body: LoadingView());
        final tabs = p.accountType == AccountType.provider
            ? _providerTabs
            : _customerTabs;
        final index = ref.watch(homeTabProvider).clamp(0, tabs.length - 1);

        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [for (final t in tabs) t.page],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) =>
                ref.read(homeTabProvider.notifier).select(i),
            destinations: [
              for (final t in tabs)
                NavigationDestination(icon: Icon(t.icon), label: t.label),
            ],
          ),
        );
      },
    );
  }
}
