import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../data/admin_catalog_repository.dart';

final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>(
  (ref) => HttpAdminCatalogRepository(ref.watch(dioProvider)),
);

/// All categories including hidden ones.
final adminCategoriesProvider = FutureProvider<List<ProductCategory>>(
  (ref) => ref.watch(adminCatalogRepositoryProvider).categories(),
);

final adminProductProvider = FutureProvider.autoDispose.family<Product, String>(
  (ref, id) => ref.watch(adminCatalogRepositoryProvider).product(id),
);

@immutable
class AdminProductFilter {
  const AdminProductFilter({this.query = '', this.status = ProductStatus.all});

  final String query;
  final ProductStatus status;

  @override
  bool operator ==(Object other) => other is AdminProductFilter && other.query == query && other.status == status;

  @override
  int get hashCode => Object.hash(query, status);
}

class AdminProductListController extends AsyncNotifier<ProductListState> {
  AdminProductListController(this.filter);

  final AdminProductFilter filter;

  AdminCatalogRepository get _repository => ref.read(adminCatalogRepositoryProvider);

  @override
  Future<ProductListState> build() async {
    ref.watch(adminCatalogRepositoryProvider);
    final page = await _repository.products(query: filter.query, status: filter.status);
    return ProductListState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(ProductListState(items: current.items, nextCursor: current.nextCursor, loadingMore: true));
    try {
      final page = await _repository.products(query: filter.query, status: filter.status, cursor: current.nextCursor);
      state = AsyncData(ProductListState(items: [...current.items, ...page.items], nextCursor: page.nextCursor));
    } on Object catch (error) {
      state = AsyncData(ProductListState(items: current.items, nextCursor: current.nextCursor, loadMoreError: error));
    }
  }

  /// Optimistic show/hide toggle; reverts and rethrows on failure.
  Future<void> setActive(Product product, {required bool isActive}) async {
    final current = state.value;
    if (current == null) return;
    List<Product> replace(Product updated) => [for (final p in current.items) p.id == updated.id ? updated : p];
    state = AsyncData(
      ProductListState(items: replace(product.copyWith(isActive: isActive)), nextCursor: current.nextCursor),
    );
    try {
      final saved = await _repository.setProductActive(product.id, isActive: isActive);
      state = AsyncData(ProductListState(items: replace(saved), nextCursor: current.nextCursor));
    } on Object {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final adminProductListProvider =
    AsyncNotifierProvider.autoDispose.family<AdminProductListController, ProductListState, AdminProductFilter>(
      AdminProductListController.new,
    );

/// After any catalog change: admin lists and customer browsing reload.
void invalidateCatalog(WidgetRef ref) {
  ref
    ..invalidate(adminProductListProvider)
    ..invalidate(adminCategoriesProvider)
    ..invalidate(adminProductProvider)
    ..invalidate(categoriesProvider)
    ..invalidate(productListProvider)
    ..invalidate(productProvider);
}
