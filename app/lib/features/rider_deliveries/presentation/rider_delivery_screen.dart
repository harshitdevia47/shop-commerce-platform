import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../delivery/domain/delivery_models.dart';
import '../../delivery/presentation/delivery_providers.dart';
import '../../delivery/presentation/delivery_widgets.dart';
import 'rider_home_screen.dart';

/// One job: where to go, whom to call, cash to collect, and the two steps
/// (picked up at the shop → delivered with the customer's code).
class RiderDeliveryScreen extends ConsumerStatefulWidget {
  const RiderDeliveryScreen({required this.deliveryId, super.key});

  final String deliveryId;

  @override
  ConsumerState<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends ConsumerState<RiderDeliveryScreen> {
  bool _busy = false;

  void _refresh() {
    ref
      ..invalidate(riderDeliveryProvider(widget.deliveryId))
      ..invalidate(riderDeliveriesProvider);
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
      return false;
    } finally {
      _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver() async {
    final otp = await showDialog<String>(context: context, builder: (_) => const _OtpDialog());
    if (otp == null) return;
    await _run(() => ref.read(riderRepositoryProvider).deliver(widget.deliveryId, otp));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final job = ref.watch(riderDeliveryProvider(widget.deliveryId));
    return Scaffold(
      appBar: AppBar(title: Text(job.value == null ? '' : l10n.orderNumber(job.value!.orderNumber))),
      body: switch (job) {
        AsyncValue(:final value?) => _body(value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: _refresh),
        _ => const SplashView(),
      },
      bottomNavigationBar: switch (job.value) {
        RiderDelivery(status: DeliveryStatus.assigned) => _action(
          key: const Key('pickUpButton'),
          label: l10n.riderPickUp,
          icon: Icons.inventory_2_outlined,
          onPressed: () => _run(() => ref.read(riderRepositoryProvider).pickUp(widget.deliveryId)),
        ),
        RiderDelivery(status: DeliveryStatus.pickedUp) => _action(
          key: const Key('deliverButton'),
          label: l10n.riderDeliver,
          icon: Icons.verified_outlined,
          onPressed: _deliver,
        ),
        _ => null,
      },
    );
  }

  Widget _action({required Key key, required String label, required IconData icon, required VoidCallback onPressed}) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: FilledButton.icon(key: key, onPressed: _busy ? null : onPressed, icon: Icon(icon), label: Text(label)),
    ),
  );

  Widget _body(RiderDelivery job) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final launch = ref.read(externalLauncherProvider);
    final address = job.address;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (job.status == DeliveryStatus.pickedUp) const SharingBanner(),
          Card(
            color: job.status == DeliveryStatus.cancelled ? theme.colorScheme.errorContainer : null,
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(job.status == DeliveryStatus.cancelled ? l10n.riderCancelledReturn : job.status.label(l10n)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(job.customer.display),
              subtitle: job.customer.name == null ? null : Text(job.customer.phone),
              trailing: IconButton(
                key: const Key('callCustomerButton'),
                tooltip: l10n.callCustomer,
                icon: const Icon(Icons.call_outlined),
                onPressed: () => launch(Uri(scheme: 'tel', path: job.customer.phone)),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(address.summary, style: theme.textTheme.bodyLarge),
                  if (job.note case final note?) Text(l10n.riderNote(note), style: theme.textTheme.bodySmall),
                  OutlinedButton.icon(
                    key: const Key('navigateButton'),
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(l10n.riderNavigate),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => launch(mapsUri(lat: address.lat, lng: address.lng, query: address.summary)),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(job.codPaise > 0 ? Icons.payments_outlined : Icons.check_circle_outline),
              title: Text(
                job.codPaise > 0 ? l10n.riderCollectCash(formatPaise(job.codPaise)) : l10n.riderPrepaid,
                key: const Key('cashToCollect'),
              ),
              subtitle: Text(l10n.riderItems(job.itemCount)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-digit code from the customer. Owns its controller (outlives the closing animation).
class _OtpDialog extends StatefulWidget {
  const _OtpDialog();

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.deliveryOtpLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.riderEnterOtp),
          const SizedBox(height: 12),
          TextField(
            key: const Key('deliveryOtpField'),
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 12),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          key: const Key('confirmOtpButton'),
          onPressed: _code.text.length == 4 ? () => Navigator.pop(context, _code.text) : null,
          child: Text(l10n.riderConfirm),
        ),
      ],
    );
  }
}
