import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/app_localizations.dart';

/// Delivery rules, payment options and enabled services of the shop.
class ShopInfoPanel extends ConsumerWidget {
  const ShopInfoPanel({required this.settings, super.key});

  final ShopSettings settings;

  static Future<void> show(BuildContext context, ShopSettings settings) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ShopInfoPanel(settings: settings),
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabledFeatures = Feature.values.where(settings.isEnabled).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(title: l10n.deliveryTitle, children: _deliveryLines(l10n, settings.delivery)),
        const SizedBox(height: 12),
        _Section(
          title: l10n.paymentTitle,
          children: [
            if (settings.payments.cod) _Line(icon: Icons.payments_outlined, text: l10n.paymentCod),
            if (settings.payments.upiEnabled) _Line(icon: Icons.qr_code_2, text: l10n.paymentUpi),
          ],
        ),
        if (enabledFeatures.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: l10n.featuresTitle,
            children: [
              for (final feature in enabledFeatures) _Line(icon: Icons.check_circle_outline, text: feature.label(l10n)),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _deliveryLines(AppLocalizations l10n, DeliveryRules delivery) {
    if (!delivery.enabled) return [_Line(icon: Icons.storefront_outlined, text: l10n.deliveryUnavailable)];
    return [
      _Line(icon: Icons.bolt_outlined, text: l10n.deliveryEta(delivery.etaMinutes)),
      if (delivery.minOrderPaise > 0)
        _Line(icon: Icons.shopping_basket_outlined, text: l10n.deliveryMinOrder(formatPaise(delivery.minOrderPaise))),
      if (delivery.feePaise > 0)
        _Line(icon: Icons.delivery_dining_outlined, text: l10n.deliveryFee(formatPaise(delivery.feePaise))),
      if (delivery.freeAbovePaise case final freeAbove?)
        _Line(icon: Icons.local_offer_outlined, text: l10n.deliveryFreeAbove(formatPaise(freeAbove))),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
