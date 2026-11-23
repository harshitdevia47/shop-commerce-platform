import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/order_models.dart';
import 'orders_providers.dart';

/// Add a delivery address. Pops with the saved [Address].
class AddressSheet extends ConsumerStatefulWidget {
  const AddressSheet({super.key});

  static Future<Address?> show(BuildContext context) => showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AddressSheet(),
  );

  @override
  ConsumerState<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends ConsumerState<AddressSheet> {
  final _form = GlobalKey<FormState>();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  String _label = 'home';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_line1, _line2, _landmark, _city, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    String? optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final address = await ref.read(ordersRepositoryProvider).addAddress({
        'label': _label,
        'line1': _line1.text.trim(),
        'line2': optional(_line2),
        'landmark': optional(_landmark),
        'city': _city.text.trim(),
        'pincode': _pincode.text.trim(),
      });
      ref.invalidate(addressesProvider);
      if (mounted) Navigator.pop(context, address);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    InputDecoration deco(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
    String? required(String? v) => v == null || v.trim().isEmpty ? l10n.requiredField : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(l10n.addAddress, style: Theme.of(context).textTheme.titleLarge),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'home', label: Text(l10n.addressHome)),
                  ButtonSegment(value: 'work', label: Text(l10n.addressWork)),
                  ButtonSegment(value: 'other', label: Text(l10n.addressOther)),
                ],
                selected: {_label},
                onSelectionChanged: (s) => setState(() => _label = s.first),
              ),
              TextFormField(key: const Key('addressLine1'), controller: _line1, decoration: deco(l10n.addressLine1), validator: required),
              TextFormField(controller: _line2, decoration: deco(l10n.addressLine2)),
              TextFormField(controller: _landmark, decoration: deco(l10n.landmarkLabel)),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextFormField(key: const Key('addressCity'), controller: _city, decoration: deco(l10n.cityLabel), validator: required),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: const Key('addressPincode'),
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: deco(l10n.pincodeLabel),
                      validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v) ? null : l10n.invalidPincode,
                    ),
                  ),
                ],
              ),
              FilledButton(
                key: const Key('saveAddressButton'),
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
