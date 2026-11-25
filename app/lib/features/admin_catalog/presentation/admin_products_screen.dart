import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/server_image.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/admin_catalog_repository.dart';
import 'admin_catalog_providers.dart';

/// Owner's product list: search, visible/hidden filter, quick show/hide, add.
class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _filter = const AdminProductFilter();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _filter = AdminProductFilter(query: value.trim(), status: _filter.status));
    });
  }

  Future<void> _toggle(Product product, bool isActive) async {
    try {
      await ref.read(adminProductListProvider(_filter).notifier).setActive(product, isActive: isActive);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = adminProductListProvider(_filter);
    final state = ref.watch(provider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminProducts),
        actions: [
          TextButton.icon(
            key: const Key('importProductsButton'),
            onPressed: () => context.push(Routes.adminImportProducts),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.importShort),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addProductButton'),
        onPressed: () => context.push(Routes.adminNewProduct),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProduct),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ProductStatus>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ProductStatus.all, label: Text(l10n.statusAll)),
                ButtonSegment(value: ProductStatus.active, label: Text(l10n.statusVisible)),
                ButtonSegment(value: ProductStatus.inactive, label: Text(l10n.statusHidden)),
              ],
              selected: {_filter.status},
              onSelectionChanged: (s) => setState(() => _filter = AdminProductFilter(query: _filter.query, status: s.first)),
            ),
          ),
          Expanded(
            child: switch (state) {
              AsyncValue(:final value?) when value.items.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      Text(l10n.noProducts, textAlign: TextAlign.center),
                      Text(l10n.importEmptyHint, textAlign: TextAlign.center),
                      OutlinedButton.icon(
                        key: const Key('importFromEmptyButton'),
                        onPressed: () => context.push(Routes.adminImportProducts),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(l10n.importTitle),
                      ),
                    ],
                  ),
                ),
              ),
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(provider),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: value.items.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == value.items.length) {
                      if (value.hasMore && value.loadMoreError == null && !value.loadingMore) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(provider.notifier).loadMore());
                      }
                      return value.loadingMore
                          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                          : const SizedBox.shrink();
                    }
                    final product = value.items[index];
                    final variant = product.defaultVariant;
                    return ListTile(
                      key: ValueKey('admin-product-${product.id}'),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox.square(dimension: 48, child: ServerImage(product.thumbUrl)),
                      ),
                      title: Text(product.localizedName(locale), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          formatPaise(variant.pricePaise),
                          if (product.variants.length > 1) l10n.variantCount(product.variants.length),
                          if (!product.inStock) l10n.outOfStock,
                        ].join(' · '),
                      ),
                      trailing: Switch(
                        value: product.isActive,
                        onChanged: (isActive) => _toggle(product, isActive),
                      ),
                      onTap: () => context.push(Routes.adminProduct(product.id)),
                    );
                  },
                ),
              ),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(provider)),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
