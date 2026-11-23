import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import 'catalog_providers.dart';
import 'widgets/product_grid.dart';

/// Products of a category, with chips for its sub-categories.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({required this.categoryId, super.key});

  final String categoryId;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  /// Selected sub-category, or null for everything in the category.
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category = categories.where((c) => c.id == widget.categoryId).firstOrNull;
    final children = categories.where((c) => c.parentId == widget.categoryId).toList();
    final filter = ProductFilter(categoryId: _selected ?? widget.categoryId);

    return Scaffold(
      bottomNavigationBar: const CartBar(),
      appBar: AppBar(title: Text(category?.localizedName(locale) ?? '')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(productListProvider(filter).notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            if (children.isNotEmpty)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.allInCategory),
                        selected: _selected == null,
                        onSelected: (_) => setState(() => _selected = null),
                      ),
                      for (final child in children)
                        ChoiceChip(
                          label: Text(child.localizedName(locale)),
                          selected: _selected == child.id,
                          onSelected: (_) => setState(() => _selected = child.id),
                        ),
                    ],
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ProductGridSliver(filter),
          ],
        ),
      ),
    );
  }
}
