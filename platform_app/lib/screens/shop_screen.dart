import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../api/admin_api.dart';
import '../api/models.dart';
import '../format.dart';
import '../providers.dart';
import 'error_view.dart';
import 'status_badge.dart';

final _random = Random.secure();

/// One id per opened form: a double tap or a retry never records a payment twice.
String newFormId() => List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

/// One shop: subscription with its actions, payments, app numbers and launch checklist.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, required this.shopId});
  final String shopId;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _busy = false;

  /// Runs an action, refreshes the page with the server's answer and says what happened.
  Future<bool> _act(String action, Map<String, Object?> body, String doneText) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      final outcome = await withToken(ref.read, (api, token) => api.act(token, widget.shopId, action, body));
      ref.invalidate(shopDetailProvider(widget.shopId));
      ref.invalidate(overviewProvider);
      messenger.showSnackBar(SnackBar(content: Text(outcome.repeat ? 'That was already saved; nothing changed.' : doneText)));
      return true;
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.display), duration: const Duration(seconds: 6)));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(shopDetailProvider(widget.shopId));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.shop.name ?? 'Shop')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(shopDetailProvider(widget.shopId))),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(shopDetailProvider(widget.shopId).future).then<void>((_) {}, onError: (_) {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ShopHeader(detail: d),
              if (d.subscription == null) _SetupCard(detail: d, onSave: _act) else ..._subscription(context, d, d.subscription!),
              const _SectionTitle('App numbers'),
              _Numbers(numbers: d.numbers),
              const _SectionTitle('Launch checklist'),
              _Checklist(detail: d, onChange: (logo, play) => _act('checklist', {'logoDone': logo, 'playDone': play}, 'Checklist saved')),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _subscription(BuildContext context, ShopDetail d, Subscription sub) {
    final theme = Theme.of(context);
    return [
      const _SectionTitle('Subscription'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(children: [const Expanded(child: Text('Status')), StatusBadge(d.status)]),
              _Line('Monthly fee', rupees(sub.feePaise)),
              _Line('Due day', '${sub.dueDay} of every month'),
              _Line('Next due', niceDate(sub.nextDueDate), key: const Key('nextDue')),
              if (sub.extendedUntil != null) _Line('Extended until', niceDate(sub.extendedUntil)),
              if (sub.pausedAt != null) _Line('Paused since', niceDate(sub.pausedAt)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const Key('markPaidButton'),
        onPressed: _busy ? null : () => _openPaid(context, d, sub),
        icon: const Icon(Icons.currency_rupee),
        label: const Text('Mark paid'),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('remindButton'),
            onPressed: () => ref.read(externalLauncherProvider)(_remindUri(d, sub)),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Remind on WhatsApp'),
          ),
          OutlinedButton.icon(
            key: const Key('extendButton'),
            onPressed: _busy ? null : () => _act('extend', {'formId': newFormId()}, 'Extended by 7 days'),
            icon: const Icon(Icons.more_time),
            label: const Text('Extend 7 days'),
          ),
          if (sub.pausedAt != null)
            OutlinedButton.icon(
              key: const Key('resumeButton'),
              onPressed: _busy ? null : () => _act('resume', {'formId': newFormId()}, 'Online orders are on again'),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Resume orders'),
            )
          else
            OutlinedButton.icon(
              key: const Key('pauseButton'),
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: _busy ? null : () => _confirmPause(context, d),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause orders'),
            ),
          OutlinedButton.icon(
            key: const Key('editButton'),
            onPressed: _busy ? null : () => _openFee(context, d, edit: true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Change fee or due day'),
          ),
        ],
      ),
      const _SectionTitle('Payments'),
      if (d.payments.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No payments recorded yet.'))
      else
        Card(
          child: Column(
            children: [
              for (final p in d.payments)
                ListTile(
                  dense: true,
                  title: Text('${rupees(p.amountPaise)} · ${niceDate(p.paidOn)}'),
                  subtitle: Text(
                    [
                      '${p.months} month${p.months == 1 ? '' : 's'}',
                      if (p.upiRef != null) 'UPI ${p.upiRef}',
                      if (p.note != null) p.note!,
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Uri _remindUri(ShopDetail d, Subscription sub) {
    final phone = (d.numbers.ownerPhone ?? d.shop.whatsapp ?? d.shop.phone).replaceAll(RegExp(r'\D'), '');
    final text = [
      'Hello from the ${d.shop.name} app team.',
      'Your monthly app subscription of ${rupees(sub.feePaise)} was due on ${niceDate(sub.nextDueDate)}.',
      if (d.payTo != null) 'Please pay by UPI to ${d.payTo} and send the screenshot here.' else 'Please pay and send the screenshot here.',
      'Thank you!',
    ].join('\n');
    return Uri.https('wa.me', '/$phone', {'text': text});
  }

  Future<void> _confirmPause(BuildContext context, ShopDetail d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause online orders?'),
        content: Text(
          'Customers of ${d.shop.name} will not be able to place new orders. They will see '
          '"This shop is not taking online orders right now. Please call the shop."\n\n'
          'The owner can still log in and finish open orders. Saving a payment turns orders on again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            key: const Key('confirmPause'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pause orders'),
          ),
        ],
      ),
    );
    if (ok == true) await _act('pause', {'formId': newFormId()}, 'Online orders are paused for ${d.shop.name}');
  }

  Future<void> _openPaid(BuildContext context, ShopDetail d, Subscription sub) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PaidSheet(
      feeRupees: sub.feePaise / 100,
      today: d.today,
      onSave: (body) => _act('paid', body, 'Payment saved. Next due date moved ahead; orders are on.'),
    ),
  );

  Future<void> _openFee(BuildContext context, ShopDetail d, {required bool edit}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FeeSheet(
      title: edit ? 'Change fee or due day' : 'Set up the subscription',
      feeRupees: d.subscription != null ? d.subscription!.feePaise / 100 : d.defaultFeeRupees?.toDouble(),
      dueDay: d.subscription?.dueDay ?? 5,
      onSave: (body) => _act(edit ? 'edit' : 'setup', body, edit ? 'Saved' : 'Subscription set up'),
    ),
  );
}

String _plain(double? rupees) => rupees == null ? '' : (rupees == rupees.roundToDouble() ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2));

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.detail});
  final ShopDetail detail;

  @override
  Widget build(BuildContext context) {
    final n = detail.numbers;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text('${detail.shop.slug} · ${detail.shop.businessType}', style: Theme.of(context).textTheme.bodySmall),
            _Line('Owner', [n.ownerName, n.ownerPhone].whereType<String>().join(' ').ifEmpty('—')),
            _Line('Shop phone', detail.shop.phone),
            _Line('Address', detail.shop.address),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.detail, required this.onSave});
  final ShopDetail detail;
  final Future<bool> Function(String action, Map<String, Object?> body, String doneText) onSave;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(children: [const Expanded(child: Text('Subscription')), StatusBadge(detail.status)]),
          const Text('This shop has no subscription yet. The first due date will be the next due day from today.'),
          FilledButton(
            key: const Key('setupButton'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => _FeeSheet(
                title: 'Set up the subscription',
                feeRupees: detail.defaultFeeRupees?.toDouble(),
                dueDay: 5,
                onSave: (body) => onSave('setup', body, 'Subscription set up'),
              ),
            ),
            child: const Text('Set up subscription'),
          ),
        ],
      ),
    ),
  );
}

class _FeeSheet extends StatefulWidget {
  const _FeeSheet({required this.title, required this.feeRupees, required this.dueDay, required this.onSave});
  final String title;
  final double? feeRupees;
  final int dueDay;
  final Future<bool> Function(Map<String, Object?> body) onSave;

  @override
  State<_FeeSheet> createState() => _FeeSheetState();
}

class _FeeSheetState extends State<_FeeSheet> {
  late final _fee = TextEditingController(text: _plain(widget.feeRupees));
  late final _day = TextEditingController(text: '${widget.dueDay}');
  final _formId = newFormId();
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    _day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Sheet(
    title: widget.title,
    saving: _saving,
    saveLabel: 'Save',
    saveKey: const Key('saveFeeButton'),
    onSave: () async {
      setState(() => _saving = true);
      final ok = await widget.onSave({'feeRupees': _fee.text.trim(), 'dueDay': int.tryParse(_day.text.trim()) ?? 0, 'formId': _formId});
      if (!context.mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _saving = false);
      }
    },
    children: [
      TextField(
        key: const Key('feeField'),
        controller: _fee,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Monthly fee (₹)', border: OutlineInputBorder()),
      ),
      TextField(
        key: const Key('dueDayField'),
        controller: _day,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Due day of the month (1–28)', border: OutlineInputBorder()),
      ),
    ],
  );
}

class _PaidSheet extends StatefulWidget {
  const _PaidSheet({required this.feeRupees, required this.today, required this.onSave});
  final double feeRupees;
  final String today;
  final Future<bool> Function(Map<String, Object?> body) onSave;

  @override
  State<_PaidSheet> createState() => _PaidSheetState();
}

class _PaidSheetState extends State<_PaidSheet> {
  late final _amount = TextEditingController(text: _plain(widget.feeRupees));
  final _months = TextEditingController(text: '1');
  final _upi = TextEditingController();
  final _note = TextEditingController();
  late String _paidOn = widget.today;
  final _formId = newFormId();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_amount, _months, _upi, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Sheet(
    title: 'Mark paid',
    saving: _saving,
    saveLabel: 'Save payment',
    saveKey: const Key('savePaymentButton'),
    onSave: () async {
      setState(() => _saving = true);
      final ok = await widget.onSave({
        'amountRupees': _amount.text.trim(),
        'months': int.tryParse(_months.text.trim()) ?? 0,
        if (_upi.text.trim().isNotEmpty) 'upiRef': _upi.text.trim(),
        'paidOn': _paidOn,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'formId': _formId,
      });
      if (!context.mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _saving = false);
      }
    },
    children: [
      TextField(
        key: const Key('amountField'),
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
      ),
      TextField(
        key: const Key('monthsField'),
        controller: _months,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Months covered', border: OutlineInputBorder()),
      ),
      TextField(
        key: const Key('upiField'),
        controller: _upi,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'UPI reference (optional)', border: OutlineInputBorder()),
      ),
      OutlinedButton.icon(
        key: const Key('paidOnButton'),
        icon: const Icon(Icons.event),
        label: Text('Paid on ${niceDate(_paidOn)}'),
        onPressed: () async {
          final today = DateTime.parse(widget.today);
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.parse(_paidOn),
            firstDate: today.subtract(const Duration(days: 365)),
            lastDate: today,
          );
          if (picked != null) setState(() => _paidOn = picked.toIso8601String().substring(0, 10));
        },
      ),
      TextField(
        key: const Key('noteField'),
        controller: _note,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
      ),
    ],
  );
}

/// Bottom sheet with a title, fields and a sticky save button, lifted above the keyboard.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children, required this.saving, required this.saveLabel, required this.saveKey, required this.onSave});
  final String title;
  final List<Widget> children;
  final bool saving;
  final String saveLabel;
  final Key saveKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            ...children,
            FilledButton(key: saveKey, onPressed: saving ? null : onSave, child: Text(saving ? 'Saving…' : saveLabel)),
          ],
        ),
      ),
    ),
  );
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.numbers});
  final ShopNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      ('Customers', count(numbers.customers)),
      ('New this month', count(numbers.newCustomers)),
      ('Active this month', count(numbers.activeCustomers)),
      ('Orders this month', count(numbers.orders)),
      ('Sales this month', numbers.salesPaise == null ? '—' : rupees(numbers.salesPaise!)),
      ('Products', count(numbers.products)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: [
            for (final (label, value) in tiles)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                      FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Last order: ${numbers.lastOrderAt == null ? 'none yet' : niceDate(numbers.lastOrderAt)}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.detail, required this.onChange});
  final ShopDetail detail;
  final void Function(bool logo, bool play) onChange;

  @override
  Widget build(BuildContext context) {
    final n = detail.numbers;
    final sub = detail.subscription;
    Widget auto(bool done, String text) => ListTile(
      dense: true,
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF2E7D32) : null),
      title: Text(text),
    );
    return Card(
      child: Column(
        children: [
          auto(true, 'Shop created'),
          auto(n.ownerLoggedIn, 'Owner logged in'),
          auto((n.products ?? 0) > 0, 'First product added'),
          auto(n.lastOrderAt != null, 'First order'),
          CheckboxListTile(
            key: const Key('logoCheck'),
            dense: true,
            value: sub?.logoDone ?? false,
            onChanged: sub == null ? null : (v) => onChange(v ?? false, sub.playDone),
            title: const Text('Real logo added'),
          ),
          CheckboxListTile(
            key: const Key('playCheck'),
            dense: true,
            value: sub?.playDone ?? false,
            onChanged: sub == null ? null : (v) => onChange(sub.logoDone, v ?? false),
            title: const Text('App on Play Store'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(text, style: Theme.of(context).textTheme.titleMedium));
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      Expanded(child: Text(value)),
    ],
  );
}
