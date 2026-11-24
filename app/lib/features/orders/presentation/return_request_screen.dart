import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../private_media/presentation/private_media.dart';
import '../domain/order_models.dart';
import 'orders_providers.dart';
import 'widgets/order_extras.dart';

/// Customer asks to return or exchange items of a delivered order.
class ReturnRequestScreen extends ConsumerStatefulWidget {
  const ReturnRequestScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends ConsumerState<ReturnRequestScreen> {
  final _reason = TextEditingController();
  final Map<String, int> _qty = {};
  ReturnKind _type = ReturnKind.returnItems;
  List<PickedAttachment> _photos = const [];
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send(Order order) async {
    setState(() => _sending = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(ordersRepositoryProvider).requestReturn(
        order.id,
        type: _type,
        reason: _reason.text.trim(),
        items: [
          for (final MapEntry(key: variantId, value: qty) in _qty.entries)
            if (qty > 0) {'variantId': variantId, 'qty': qty},
        ],
        photoIds: [for (final p in _photos) p.attachment.id],
      );
      ref.invalidate(orderProvider(order.id));
      messenger.showSnackBar(SnackBar(content: Text(l10n.returnSent)));
      if (mounted) context.pop();
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = ref.watch(orderProvider(widget.orderId));
    final policy = ref.watch(shopSettingsProvider).value?.returns;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestReturn)),
      body: switch (order) {
        AsyncValue(:final value?) => _form(value, policy?.allowExchange ?? false),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
        _ => const SplashView(),
      },
      bottomNavigationBar: switch (order.value) {
        final value? => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              key: const Key('sendReturnButton'),
              onPressed: _ready(value) && !_sending ? () => _send(value) : null,
              child: Text(l10n.sendRequest),
            ),
          ),
        ),
        _ => null,
      },
    );
  }

  bool _ready(Order order) =>
      _reason.text.trim().length >= 3 && (order.items.isEmpty || _qty.values.any((q) => q > 0));

  Widget _form(Order order, bool allowExchange) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (allowExchange) ...[
          SegmentedButton<ReturnKind>(
            segments: [
              for (final kind in ReturnKind.values) ButtonSegment(value: kind, label: Text(kind.label(l10n))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
        ],
        if (order.items.isNotEmpty) ...[
          Text(l10n.returnItemsTitle, style: Theme.of(context).textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                for (final item in order.items)
                  if (item.variantId case final variantId?)
                    ListTile(
                      title: Text(item.localizedName(locale)),
                      subtitle: Text(item.localizedLabel(locale)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: (_qty[variantId] ?? 0) > 0 ? () => setState(() => _qty[variantId] = _qty[variantId]! - 1) : null,
                          ),
                          Text('${_qty[variantId] ?? 0}/${item.qty}', key: ValueKey('return-qty-$variantId')),
                          IconButton(
                            key: ValueKey('return-add-$variantId'),
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (_qty[variantId] ?? 0) < item.qty
                                ? () => setState(() => _qty[variantId] = (_qty[variantId] ?? 0) + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const Key('returnReasonField'),
          controller: _reason,
          maxLength: 500,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l10n.returnReasonLabel, border: const OutlineInputBorder()),
        ),
        AttachmentField(
          kind: AttachmentKind.returnPhoto,
          label: l10n.returnPhotosLabel,
          value: _photos,
          onChanged: (v) => setState(() => _photos = v),
        ),
      ],
    );
  }
}
