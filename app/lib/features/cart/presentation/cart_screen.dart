import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/server_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/widgets/bill_summary.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'cart_quote.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cart = ref.watch(cartProvider);
    final quote = ref.watch(cartQuoteProvider);
    final settings = ref.watch(shopSettingsProvider).value;
    final fulfillment = ref.watch(fulfillmentProvider);
    final signedIn = ref.watch(authControllerProvider).value != null;

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cartTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_basket_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(l10n.cartEmpty),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.go(Routes.home), child: Text(l10n.startShopping)),
            ],
          ),
        ),
      );
    }

    final q = quote.value;
    final canPickup = settings?.isEnabled(Feature.storePickup) ?? false;
    final canDeliver = settings?.delivery.enabled ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cartQuoteProvider),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (canPickup && canDeliver)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<Fulfillment>(
                  segments: [
                    ButtonSegment(value: Fulfillment.delivery, label: Text(l10n.deliveryOption), icon: const Icon(Icons.delivery_dining_outlined)),
                    ButtonSegment(value: Fulfillment.pickup, label: Text(l10n.pickupOption), icon: const Icon(Icons.storefront_outlined)),
                  ],
                  selected: {fulfillment},
                  onSelectionChanged: (s) => ref.read(fulfillmentProvider.notifier).set(s.first),
                ),
              ),
            Card(
              child: Column(
                children: [for (final line in cart.lines) _CartLineTile(line: line, quoteLine: q?.lineFor(line.variantId))],
              ),
            ),
            const SizedBox(height: 12),
            if (q != null) ...[
              if (q.belowMinimum)
                _Hint(
                  icon: Icons.info_outline,
                  text: l10n.minOrderGap(formatPaise(q.minOrderPaise - q.subtotalPaise), formatPaise(q.minOrderPaise)),
                  error: true,
                )
              else if (q.freeDeliveryGapPaise case final gap?)
                _Hint(icon: Icons.local_offer_outlined, text: l10n.freeDeliveryGap(formatPaise(gap))),
              BillSummary(
                subtotalPaise: q.subtotalPaise,
                deliveryFeePaise: q.deliveryFeePaise,
                totalPaise: q.totalPaise,
                savingsPaise: q.savingsPaise,
                showDelivery: fulfillment == Fulfillment.delivery,
              ),
            ] else if (quote.hasError)
              _Hint(icon: Icons.cloud_off_outlined, text: errorMessage(l10n, quote.error!), error: true)
            else
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: signedIn
              ? FilledButton(
                  key: const Key('proceedButton'),
                  onPressed: q != null && q.canPlace && !quote.isLoading ? () => context.push(Routes.checkout) : null,
                  child: Text(q == null ? l10n.proceed : '${l10n.proceed} · ${formatPaise(q.totalPaise)}'),
                )
              : FilledButton(
                  key: const Key('loginToOrderButton'),
                  onPressed: () => context.push('${Routes.login}?from=${Routes.checkout}'),
                  child: Text(l10n.loginToOrder),
                ),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line, required this.quoteLine});

  final CartLine line;
  final QuoteLine? quoteLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final controller = ref.read(cartProvider.notifier);
    final issue = quoteLine?.issue;
    // Show the server's current price once known.
    final lineTotal = quoteLine?.lineTotalPaise ?? line.lineTotalPaise;

    return Padding(
      key: ValueKey('cart-line-${line.variantId}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(dimension: 56, child: ServerImage(line.thumbUrl)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.localizedName(locale), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (line.label.isNotEmpty)
                  Text(line.localizedLabel(locale), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 4),
                Text(formatPaise(lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                // Wrap, not Row: the fix button drops below the message on narrow phones.
                if (issue == 'UNAVAILABLE')
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.lineUnavailable, style: TextStyle(color: theme.colorScheme.error)),
                      TextButton(onPressed: () => controller.setQty(line.variantId, 0), child: Text(l10n.remove)),
                    ],
                  ),
                if (issue == 'INSUFFICIENT_STOCK' && quoteLine!.maxQty != null)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.lineOnlyLeft(quoteLine!.maxQty!), style: TextStyle(color: theme.colorScheme.error)),
                      TextButton(
                        onPressed: () => controller.setQty(line.variantId, quoteLine!.maxQty!),
                        child: Text(l10n.setQtyTo(quoteLine!.maxQty!)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            height: 36,
            child: Container(
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: IconButton(
                      key: ValueKey('cart-minus-${line.variantId}'),
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onPrimary,
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () => controller.decrement(line.variantId),
                    ),
                  ),
                  Text('${line.qty}', style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: IconButton(
                      key: ValueKey('cart-plus-${line.variantId}'),
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onPrimary,
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: line.qty >= Cart.maxQty ? null : () => controller.increment(line.variantId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
