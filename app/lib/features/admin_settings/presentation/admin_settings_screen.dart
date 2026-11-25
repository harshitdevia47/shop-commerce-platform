import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money.dart';
import '../data/shop_settings_admin_api.dart';

/// Owner: the shop's own settings (taking orders, delivery, payments, slots, returns, extras, contact).
/// Shop name, branding and catalog shape stay with the platform team.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(shopSettingsProvider);
    return switch (settings) {
      AsyncValue(:final value?) => _SettingsForm(key: ValueKey(value), initial: value),
      AsyncValue(:final error?) => Scaffold(
        appBar: AppBar(title: Text(l10n.adminSettings)),
        body: Center(child: Text(errorMessage(l10n, error))),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.adminSettings)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.initial});

  final ShopSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  late final ShopSettings s = widget.initial;

  // Taking orders
  late bool _paused = s.ordering.paused;
  late final _pausedMessage = TextEditingController(text: s.ordering.message ?? '');

  // Delivery / pickup
  late bool _delivery = s.delivery.enabled;
  late bool _pickup = s.isEnabled(Feature.storePickup);
  late final _fee = TextEditingController(text: paiseToInput(s.delivery.feePaise));
  late final _minOrder = TextEditingController(text: paiseToInput(s.delivery.minOrderPaise));
  late final _freeAbove = TextEditingController(
    text: s.delivery.freeAbovePaise == null ? '' : paiseToInput(s.delivery.freeAbovePaise!),
  );
  late final _radius = TextEditingController(text: _trimNumber(s.delivery.radiusKm));
  late final _eta = TextEditingController(text: '${s.delivery.etaMinutes}');
  late final _pincodes = TextEditingController(text: s.delivery.pincodes.join(', '));

  // Slots
  late bool _slotsOn = s.isEnabled(Feature.deliverySlots);
  late List<SlotWindow> _windows = [...?s.delivery.slots?.windows];
  late final _capacity = TextEditingController(text: '${s.delivery.slots?.capacityPerSlot ?? 10}');

  // Payments
  late bool _cod = s.payments.cod;
  late bool _upi = s.payments.upiEnabled;
  late final _vpa = TextEditingController(text: s.payments.upiVpa ?? '');
  late final _payee = TextEditingController(text: s.payments.upiPayeeName ?? '');

  // Returns
  late bool _returns = s.isEnabled(Feature.returns);
  late final _returnDays = TextEditingController(text: '${s.returns.windowDays}');
  late bool _exchange = s.returns.allowExchange;

  // Extras
  late bool _notes = s.isEnabled(Feature.orderNotes);
  late bool _listUpload = s.isEnabled(Feature.handwrittenListUpload);
  late bool _prescription = s.isEnabled(Feature.prescriptionUpload);

  // Contact
  late final _phone = TextEditingController(text: _localPhone(s.shop.phone));
  late final _whatsapp = TextEditingController(text: s.shop.whatsapp == null ? '' : _localPhone(s.shop.whatsapp!));
  late final _address = TextEditingController(text: s.shop.address);

  static String _trimNumber(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  static String _localPhone(String e164) => e164.startsWith('+91') ? e164.substring(3) : e164;

  @override
  void dispose() {
    for (final c in [
      _pausedMessage, _fee, _minOrder, _freeAbove, _radius, _eta, _pincodes, _capacity, //
      _vpa, _payee, _returnDays, _phone, _whatsapp, _address,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Validators (mirror the server rules so the owner sees problems next to the field) ----

  String? _money(String? v, {bool optional = false}) {
    final text = v?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    return parseRupees(text) == null ? context.l10n.settingsInvalidAmount : null;
  }

  String? _wholeNumber(String? v, int min, int max) {
    final n = int.tryParse(v?.trim() ?? '');
    return n == null || n < min || n > max ? context.l10n.settingsNumberRange(min, max) : null;
  }

  String? _radiusValidator(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    return n == null || n <= 0 || n > 50 ? context.l10n.settingsNumberRange(1, 50) : null;
  }

  List<String> get _pincodeList =>
      _pincodes.text.split(RegExp(r'[\s,]+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  String? _pincodeValidator(String? _) =>
      _pincodeList.every((p) => RegExp(r'^\d{6}$').hasMatch(p)) ? null : context.l10n.settingsInvalidPincodes;

  String? _phoneValidator(String? v, {bool optional = false}) {
    final text = v?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(text) ? null : context.l10n.errorPhoneInvalid;
  }

  String? _vpaValidator(String? v) {
    if (!_upi) return null;
    return RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z]{2,64}$').hasMatch(v?.trim() ?? '')
        ? null
        : context.l10n.settingsInvalidUpi;
  }

  /// Rules across sections; null when fine.
  String? _crossCheck() {
    final l10n = context.l10n;
    if (!_delivery && !_pickup) return l10n.settingsNeedDeliveryOrPickup;
    if (!_cod && !_upi && !s.payments.razorpayEnabled) return l10n.settingsNeedPayment;
    if (_delivery && _slotsOn && _windows.isEmpty) return l10n.settingsNeedSlot;
    return null;
  }

  Map<String, dynamic> _patch() {
    final slotsOn = _delivery && _slotsOn;
    return {
      'ordering': {
        'paused': _paused,
        'pausedMessage': _pausedMessage.text.trim().isEmpty ? null : _pausedMessage.text.trim(),
      },
      'delivery': {
        'enabled': _delivery,
        'feePaise': parseRupees(_fee.text)!,
        'minOrderPaise': parseRupees(_minOrder.text)!,
        'freeAbovePaise': _freeAbove.text.trim().isEmpty ? null : parseRupees(_freeAbove.text)!,
        'radiusKm': double.parse(_radius.text.trim()),
        'etaMinutes': int.parse(_eta.text.trim()),
        'pincodes': _pincodeList,
        if (_windows.isNotEmpty)
          'slots': SlotSettings(
            windows: _windows,
            daysAhead: s.delivery.slots?.daysAhead ?? 2,
            capacityPerSlot: int.parse(_capacity.text.trim()),
            cutoffMinutes: s.delivery.slots?.cutoffMinutes ?? 60,
          ).toJson()
        else
          'slots': null,
      },
      'payments': {
        'cod': _cod,
        'upi': {
          'enabled': _upi,
          if (_vpa.text.trim().isNotEmpty) 'vpa': _vpa.text.trim(),
          if (_payee.text.trim().isNotEmpty) 'payeeName': _payee.text.trim(),
        },
      },
      'features': {
        'storePickup': _pickup,
        'deliverySlots': slotsOn,
        'returns': _returns,
        'orderNotes': _notes,
        'handwrittenListUpload': _listUpload,
        'prescriptionUpload': _prescription,
      },
      'returns': {'windowDays': int.parse(_returnDays.text.trim()), 'allowExchange': _exchange},
      'contact': {
        'phone': '+91${_phone.text.trim()}',
        'whatsapp': _whatsapp.text.trim().isEmpty ? null : '+91${_whatsapp.text.trim()}',
        'address': _address.text.trim(),
      },
    };
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar(); // newest problem first, not queued
    if (!_form.currentState!.validate()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsFixFields)));
      return;
    }
    final problem = _crossCheck();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(shopSettingsAdminApiProvider).save(_patch());
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
      await ref.read(shopSettingsProvider.notifier).refresh();
    } on Object catch (error) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
  }

  Future<void> _addWindow() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: context.l10n.settingsSlotStart,
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
      helpText: context.l10n.settingsSlotEnd,
    );
    if (end == null || !mounted) return;
    String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final window = (start: hhmm(start), end: hhmm(end));
    if (window.start.compareTo(window.end) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.settingsSlotOrder)));
      return;
    }
    setState(() => _windows = [..._windows, window]..sort((a, b) => a.start.compareTo(b.start)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      String? Function(String?)? validator,
      List<TextInputFormatter>? formatters,
      TextInputType? keyboard,
      String? hint,
      String? prefix,
      String? suffix,
      int maxLines = 1,
    }) => TextFormField(
      key: Key(key),
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixText: prefix, suffixText: suffix),
      validator: validator,
      inputFormatters: formatters,
      keyboardType: keyboard,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );

    Widget toggle(String key, String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) =>
        SwitchListTile(
          key: Key(key),
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: (v) => setState(() => onChanged(v)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminSettings)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('saveSettingsButton'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(l10n.settingsSave),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---- Taking orders ----
            Card(
              color: _paused ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    toggle(
                      'acceptingOrdersSwitch',
                      l10n.settingsAcceptingOrders,
                      !_paused,
                      (v) => _paused = !v,
                      subtitle: _paused ? l10n.settingsPausedHint : l10n.settingsOpenHint,
                    ),
                    if (_paused)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: field(
                          'pausedMessageField',
                          _pausedMessage,
                          l10n.settingsPausedMessage,
                          hint: l10n.settingsPausedMessageHint,
                          validator: (v) => (v?.length ?? 0) > 200 ? l10n.settingsTooLong : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            _Section(l10n.settingsDeliverySection, icon: Icons.delivery_dining_outlined),
            toggle('deliverySwitch', l10n.settingsHomeDelivery, _delivery, (v) => _delivery = v),
            if (_delivery) ...[
              field(
                'feeField',
                _fee,
                l10n.settingsDeliveryFee,
                prefix: '₹ ',
                validator: _money,
                formatters: money,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              field(
                'minOrderField',
                _minOrder,
                l10n.settingsMinOrder,
                prefix: '₹ ',
                validator: _money,
                formatters: money,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              field(
                'freeAboveField',
                _freeAbove,
                l10n.settingsFreeAbove,
                prefix: '₹ ',
                hint: l10n.settingsFreeAboveHint,
                validator: (v) => _money(v, optional: true),
                formatters: money,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              field(
                'radiusField',
                _radius,
                l10n.settingsRadius,
                suffix: 'km',
                validator: _radiusValidator,
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              field(
                'etaField',
                _eta,
                l10n.settingsEta,
                suffix: l10n.settingsMinutes,
                validator: (v) => _wholeNumber(v, 1, 1440),
                formatters: digits,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              field(
                'pincodesField',
                _pincodes,
                l10n.settingsPincodes,
                hint: l10n.settingsPincodesHint,
                validator: _pincodeValidator,
                keyboard: TextInputType.number,
                maxLines: 2,
              ),
            ],
            toggle('pickupSwitch', l10n.settingsPickup, _pickup, (v) => _pickup = v, subtitle: l10n.settingsPickupHint),

            if (_delivery) ...[
              _Section(l10n.settingsSlotsSection, icon: Icons.schedule_outlined),
              toggle(
                'slotsSwitch',
                l10n.settingsSlots,
                _slotsOn,
                (v) => _slotsOn = v,
                subtitle: l10n.settingsSlotsHint,
              ),
              if (_slotsOn) ...[
                for (final w in _windows)
                  ListTile(
                    key: ValueKey('slot-${w.start}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text('${w.start} – ${w.end}'),
                    trailing: IconButton(
                      tooltip: l10n.settingsSlotRemove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _windows = [..._windows]..remove(w)),
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const Key('addSlotButton'),
                    onPressed: _windows.length >= 12 ? null : _addWindow,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.settingsSlotAdd),
                  ),
                ),
                const SizedBox(height: 12),
                field(
                  'capacityField',
                  _capacity,
                  l10n.settingsSlotCapacity,
                  validator: (v) => _wholeNumber(v, 1, 500),
                  formatters: digits,
                  keyboard: TextInputType.number,
                ),
              ],
            ],

            _Section(l10n.settingsPaymentsSection, icon: Icons.payments_outlined),
            toggle('codSwitch', l10n.settingsCod, _cod, (v) => _cod = v),
            toggle('upiSwitch', l10n.settingsUpi, _upi, (v) => _upi = v, subtitle: l10n.settingsUpiHint),
            if (_upi) ...[
              field(
                'vpaField',
                _vpa,
                l10n.settingsUpiId,
                hint: 'shopname@okaxis',
                validator: _vpaValidator,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              field(
                'payeeField',
                _payee,
                l10n.settingsUpiName,
                validator: (v) =>
                    !_upi || ((v?.trim().length ?? 0) >= 1 && v!.trim().length <= 50) ? null : l10n.settingsRequired,
              ),
            ],
            if (s.payments.razorpayEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card),
                title: Text(l10n.settingsOnlineOn),
                subtitle: Text(l10n.settingsOnlineHint),
              ),

            _Section(l10n.settingsReturnsSection, icon: Icons.assignment_return_outlined),
            toggle('returnsSwitch', l10n.settingsReturns, _returns, (v) => _returns = v),
            if (_returns) ...[
              field(
                'returnDaysField',
                _returnDays,
                l10n.settingsReturnDays,
                suffix: l10n.settingsDays,
                validator: (v) => _wholeNumber(v, 1, 60),
                formatters: digits,
                keyboard: TextInputType.number,
              ),
              toggle('exchangeSwitch', l10n.settingsExchange, _exchange, (v) => _exchange = v),
            ],

            _Section(l10n.settingsExtrasSection, icon: Icons.tune),
            toggle('notesSwitch', l10n.settingsOrderNotes, _notes, (v) => _notes = v),
            toggle(
              'listUploadSwitch',
              l10n.settingsListUpload,
              _listUpload,
              (v) => _listUpload = v,
              subtitle: l10n.settingsListUploadHint,
            ),
            toggle('prescriptionSwitch', l10n.settingsPrescription, _prescription, (v) => _prescription = v),

            _Section(l10n.settingsContactSection, icon: Icons.storefront_outlined),
            field(
              'phoneField',
              _phone,
              l10n.settingsShopPhone,
              prefix: '+91 ',
              validator: _phoneValidator,
              formatters: [...digits, LengthLimitingTextInputFormatter(10)],
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            field(
              'whatsappField',
              _whatsapp,
              l10n.settingsShopWhatsapp,
              prefix: '+91 ',
              validator: (v) => _phoneValidator(v, optional: true),
              formatters: [...digits, LengthLimitingTextInputFormatter(10)],
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            field(
              'addressField',
              _address,
              l10n.settingsShopAddress,
              validator: (v) => (v?.trim().isEmpty ?? true) ? l10n.settingsRequired : null,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(l10n.settingsPlatformNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Row(
      spacing: 8,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      ],
    ),
  );
}
