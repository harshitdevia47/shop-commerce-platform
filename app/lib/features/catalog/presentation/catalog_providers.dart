import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => HttpCatalogRepository(ref.watch(dioProvider)));

final categoriesProvider = FutureProvider<List<ProductCategory>>((ref) => ref.watch(catalogRepositoryProvider).categories());

final productProvider = FutureProvider.family<Product, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).product(id),
);

/// What a product list shows: a category, a search, or everything.
@immutable
class ProductFilter {
  const ProductFilter({this.categoryId, this.query});

  final String? categoryId;
  final String? query;

  @override
  bool operator ==(Object other) => other is ProductFilter && other.categoryId == categoryId && other.query == query;

  @override
  int get hashCode => Object.hash(categoryId, query);
}

/// State of an infinitely scrolling list.
@immutable
class ProductListState {
  const ProductListState({this.items = const [], this.nextCursor, this.loadingMore = false, this.loadMoreError});

  final List<Product> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

class ProductListController extends AsyncNotifier<ProductListState> {
  ProductListController(this.filter);

  final ProductFilter filter;

  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  @override
  Future<ProductListState> build() async {
    ref.watch(catalogRepositoryProvider);
    final page = await _repository.products(categoryId: filter.categoryId, query: filter.query);
    return ProductListState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Loads the next page; ignored while already loading or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(ProductListState(items: current.items, nextCursor: current.nextCursor, loadingMore: true));
    try {
      final page = await _repository.products(
        categoryId: filter.categoryId,
        query: filter.query,
        cursor: current.nextCursor,
      );
      state = AsyncData(ProductListState(items: [...current.items, ...page.items], nextCursor: page.nextCursor));
    } on Object catch (error) {
      state = AsyncData(ProductListState(items: current.items, nextCursor: current.nextCursor, loadMoreError: error));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // shown through state
    }
  }
}

final productListProvider = AsyncNotifierProvider.autoDispose.family<ProductListController, ProductListState, ProductFilter>(
  ProductListController.new,
);
