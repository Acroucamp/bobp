import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/utils/open_link.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await openLink(uri.toString());
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Profile? profile) async {
    final isProvider = profile?.isProvider ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(isProvider: isProvider),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // The router sends the user to the sign-in screen.
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Could not load your profile.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(p?.fullName.isNotEmpty == true ? p!.fullName : 'Your name'),
              subtitle: Text(p?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(p?.accountType.label ?? ''),
              subtitle: const Text('Account type'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              onTap: () => _open(context, Uri.parse(AppConfig.privacyPolicyUrl)),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact support'),
              subtitle: const Text(AppConfig.supportEmail),
              onTap: () => _open(
                  context, Uri(scheme: 'mailto', path: AppConfig.supportEmail)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _confirmDelete(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.isProvider});
  final bool isProvider;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text.trim() == 'DELETE';
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isProvider
              ? 'This permanently deletes your account, your businesses, their '
              'services and all of their bookings. Customers will lose '
              'those bookings. This cannot be undone.'
              : 'This permanently deletes your account and your profile. '
              'Businesses you booked with keep a record of the booking '
              'without your name. This cannot be undone.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
