import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../data/services_repository.dart';
import '../domain/service.dart';

/// Bottom sheet for adding a service, or editing one when [service] is given.
Future<void> showServiceFormSheet(
    BuildContext context, {
      required String businessId,
      Service? service,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ServiceForm(businessId: businessId, service: service),
  );
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({required this.businessId, this.service});
  final String businessId;
  final Service? service;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _price = TextEditingController(
    text: widget.service == null
        ? ''
        : (widget.service!.priceCents / 100).toStringAsFixed(2),
  );
  late final _duration = TextEditingController(
    text: widget.service?.durationMinutes.toString() ?? '60',
  );
  late bool _active = widget.service?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(servicesRepositoryProvider);
    final cents = Money.parseToCents(_price.text)!;
    final minutes = int.parse(_duration.text.trim());
    try {
      if (widget.service == null) {
        await repo.create(
          businessId: widget.businessId,
          name: _name.text,
          priceCents: cents,
          durationMinutes: minutes,
          isActive: _active,
        );
      } else {
        await repo.update(
          id: widget.service!.id,
          name: _name.text,
          priceCents: cents,
          durationMinutes: minutes,
          isActive: _active,
        );
      }
      ref.invalidate(servicesProvider(widget.businessId));
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.service != null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing ? 'Edit service' : 'New service',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
              const InputDecoration(labelText: 'Price (ZAR)', prefixText: 'R '),
              validator: (v) => Money.parseToCents(v ?? '') == null
                  ? 'Enter an amount like 250 or 250.50'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration:
              const InputDecoration(labelText: 'Duration', suffixText: 'min'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 5 || n > 1440) return 'Enter 5 to 1440 minutes';
                return null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for booking'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(editing ? 'Save changes' : 'Add service'),
            ),
          ],
        ),
      ),
    );
  }
}
