import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/server_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../cart/presentation/widgets/add_to_cart_button.dart';
import '../../domain/catalog_models.dart';
import 'price_tag.dart';

/// Grid tile: image, name, unit, price. Tapping opens the product.
class ProductCard extends ConsumerWidget {
  const ProductCard(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final variant = product.defaultVariant;
    final variantText = product.variants.length > 1
        ? context.l10n.variantCount(product.variants.length)
        : variant.localizedLabel(locale);

    return Card(
      key: ValueKey('product-${product.id}'),
      child: InkWell(
        onTap: () => context.push(Routes.product(product.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The image absorbs leftover height, so long names, big fonts or a wrapped price never overflow.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServerImage(product.thumbUrl),
                  if (!product.inStock)
                    ColoredBox(
                      color: theme.colorScheme.surface.withValues(alpha: 0.6),
                      child: Center(child: Chip(label: Text(context.l10n.outOfStock))),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                product.localizedName(locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (variantText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(variantText, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ),
            // Price and ADD stacked: side by side they do not fit two-column grids on small phones.
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 6), child: PriceTag(variant)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(width: double.infinity, child: AddToCartButton(product: product, dense: true)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SkeletonBox(radius: 0)),
          Padding(padding: EdgeInsets.all(8), child: SkeletonBox(height: 14, width: 100)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SkeletonBox(height: 12, width: 60)),
        ],
      ),
    );
  }
}

/// Grid delegate shared by every product grid: 2 columns on phones, more on wide screens.
const productGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 220,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  mainAxisExtent: 320,
);
