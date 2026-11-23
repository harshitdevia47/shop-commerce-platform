import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/server_image.dart';
import '../../../core/widgets/splash_view.dart';
import '../../cart/presentation/widgets/add_to_cart_button.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import '../domain/catalog_models.dart';
import 'catalog_providers.dart';
import 'widgets/price_tag.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    return Scaffold(
      appBar: AppBar(title: Text(product.value?.localizedName(ref.watch(localeProvider)) ?? '')),
      bottomNavigationBar: const CartBar(),
      body: switch (product) {
        AsyncValue(:final value?) => _ProductBody(product: value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(productProvider(productId))),
        _ => const SplashView(),
      },
    );
  }
}

class _ProductBody extends ConsumerStatefulWidget {
  const _ProductBody({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends ConsumerState<_ProductBody> {
  late Variant _variant = widget.product.defaultVariant;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final product = widget.product;
    final fields = ref.watch(shopSettingsProvider).value?.catalog.customFields ?? const <CustomFieldDef>[];
    final description = product.localizedDescription(locale);
    final details = [
      for (final field in fields)
        if (product.customFields[field.key] case final value? when value != false && value != '')
          (field.localizedLabel(locale), value == true ? '✓' : '$value'),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: product.images.isEmpty
              ? const ServerImage(null)
              : Stack(
                  children: [
                    PageView(
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [for (final image in product.images) ServerImage(image.url, fit: BoxFit.contain)],
                    ),
                    if (product.images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 6,
                          children: [
                            for (var i = 0; i < product.images.length; i++)
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(product.localizedName(locale), style: theme.textTheme.headlineSmall),
              if (_variant.localizedLabel(locale).isNotEmpty)
                Text(_variant.localizedLabel(locale), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              PriceTag(_variant, large: true),
              if (!_variant.inStock)
                Text(l10n.outOfStock, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (product.variants.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.chooseVariant, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final variant in product.variants)
                  ChoiceChip(
                    key: ValueKey('variant-${variant.id}'),
                    label: Text(variant.localizedLabel(locale)),
                    selected: variant.id == _variant.id,
                    onSelected: (_) => setState(() => _variant = variant),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _variant.inStock
              ? AddToCartButton(product: product, variant: _variant)
              : FilledButton.tonal(onPressed: null, child: Text(l10n.outOfStock)),
        ),
        if (description != null || details.isNotEmpty) ...[
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(l10n.productDetails, style: theme.textTheme.titleMedium),
                for (final (label, value) in details)
                  Row(
                    children: [
                      SizedBox(width: 120, child: Text(label, style: TextStyle(color: theme.colorScheme.outline))),
                      Expanded(child: Text(value)),
                    ],
                  ),
                if (description != null) Text(description),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
