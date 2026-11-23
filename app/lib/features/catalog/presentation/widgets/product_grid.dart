import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/error_view.dart';
import '../catalog_providers.dart';
import 'product_card.dart';

/// Infinite product grid for a [ProductFilter], as slivers (put inside a CustomScrollView).
/// Loads the next page when the user nears the end.
class ProductGridSliver extends ConsumerWidget {
  const ProductGridSliver(this.filter, {this.empty, super.key});

  final ProductFilter filter;

  /// Shown when the list is empty; defaults to "No products here yet".
  final Widget? empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = productListProvider(filter);
    final state = ref.watch(provider);
    const padding = EdgeInsets.fromLTRB(12, 0, 12, 12);

    return switch (state) {
      AsyncValue(:final value?) when value.items.isEmpty => SliverFillRemaining(
        hasScrollBody: false,
        child: empty ?? _Empty(text: context.l10n.noProducts),
      ),
      AsyncValue(:final value?) => SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverGrid.builder(
              gridDelegate: productGridDelegate,
              itemCount: value.items.length,
              itemBuilder: (context, index) {
                if (index >= value.items.length - 4 && value.hasMore && value.loadMoreError == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(provider.notifier).loadMore());
                }
                return ProductCard(value.items[index]);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                child: switch (value) {
                  _ when value.loadingMore => const CircularProgressIndicator(),
                  _ when value.loadMoreError != null => TextButton(
                    onPressed: () => ref.read(provider.notifier).loadMore(),
                    child: Text(context.l10n.loadMoreFailed),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ],
      ),
      AsyncValue(:final error?) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(error: error, onRetry: () => ref.read(provider.notifier).refresh()),
      ),
      _ => SliverPadding(
        padding: padding,
        sliver: SliverGrid.builder(
          gridDelegate: productGridDelegate,
          itemCount: 6,
          itemBuilder: (_, _) => const ProductCardSkeleton(),
        ),
      ),
    };
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
