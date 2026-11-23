import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/providers.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../../catalog/presentation/widgets/price_tag.dart';
import '../../domain/cart.dart';
import '../cart_controller.dart';

/// "ADD" button that turns into a − qty + stepper.
/// With [variant] null and several variants, ADD opens a picker instead (product cards).
class AddToCartButton extends ConsumerWidget {
  const AddToCartButton({required this.product, this.variant, this.dense = false, super.key});

  final Product product;
  final Variant? variant;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);
    final chosen = variant ?? (product.variants.length == 1 ? product.variants.first : null);
    final theme = Theme.of(context);
    final height = dense ? 34.0 : 44.0;

    Widget addButton(VoidCallback onPressed) => SizedBox(
      height: height,
      child: OutlinedButton(
        key: ValueKey('add-${product.id}'),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: theme.colorScheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(context.l10n.addToCart, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    if (chosen == null) {
      // Several variants: ADD and the stepper both open the picker; the stepper shows the total.
      if (!product.inStock) return SizedBox(height: height);
      final qty = cart.qtyOfProduct(product.id);
      if (qty == 0) return addButton(() => _pick(context, ref));
      return _Stepper(
        keyPrefix: product.id,
        height: height,
        qty: qty,
        onMinus: () => _pick(context, ref),
        onPlus: () => _pick(context, ref),
      );
    }

    if (!chosen.inStock) return SizedBox(height: height);
    final qty = cart.qtyOf(chosen.id);
    if (qty == 0) return addButton(() => controller.add(product, chosen));
    return _Stepper(
      keyPrefix: chosen.id,
      height: height,
      qty: qty,
      onMinus: () => controller.decrement(chosen.id),
      onPlus: qty >= Cart.maxQty ? null : () => controller.increment(chosen.id),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _VariantPicker(product: product),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.keyPrefix, required this.height, required this.qty, required this.onMinus, this.onPlus});

  final String keyPrefix;
  final double height;
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: IconButton(
              key: ValueKey('minus-$keyPrefix'),
              padding: EdgeInsets.zero,
              color: scheme.onPrimary,
              icon: const Icon(Icons.remove, size: 18),
              onPressed: onMinus,
            ),
          ),
          Text(
            '$qty',
            key: ValueKey('qty-$keyPrefix'),
            style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: IconButton(
              key: ValueKey('plus-$keyPrefix'),
              padding: EdgeInsets.zero,
              color: scheme.onPrimary,
              icon: const Icon(Icons.add, size: 18),
              onPressed: onPlus,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing a product's variants, each with its own stepper.
class _VariantPicker extends ConsumerWidget {
  const _VariantPicker({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.localizedName(locale), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final variant in product.variants)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(variant.localizedLabel(locale)), PriceTag(variant)],
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: variant.inStock
                          ? AddToCartButton(product: product, variant: variant, dense: true)
                          : Text(context.l10n.outOfStock, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
