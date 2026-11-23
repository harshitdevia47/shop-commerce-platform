import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/server_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../catalog_providers.dart';

/// Horizontal list of top-level categories with images. Hidden when the shop has none.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  static const _height = 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final categories = ref.watch(categoriesProvider);
    return switch (categories) {
      AsyncValue(:final value?) => Builder(
        builder: (context) {
          final topLevel = value.where((c) => c.isTopLevel).toList();
          if (topLevel.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: _height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: topLevel.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = topLevel[index];
                return InkWell(
                  key: ValueKey('category-${category.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(Routes.category(category.id)),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(
                            dimension: 64,
                            child: ServerImage(category.imageUrl, icon: Icons.category_outlined),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category.localizedName(locale),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      AsyncValue(hasError: true) => const SizedBox.shrink(),
      _ => SizedBox(
        height: _height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const SkeletonBox(width: 64, height: 64, radius: 12),
        ),
      ),
    };
  }
}
