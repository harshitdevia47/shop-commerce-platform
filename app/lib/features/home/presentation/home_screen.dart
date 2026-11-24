import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/splash_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/widgets/category_strip.dart';
import '../../catalog/presentation/widgets/product_grid.dart';
import 'shop_info_sheet.dart';

/// Customer home: search, categories and all products of the shop.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(shopSettingsProvider);
    return switch (settings) {
      AsyncValue(:final value?) => _HomeContent(settings: value),
      AsyncValue(:final error?) => Scaffold(
        body: ErrorView(error: error, onRetry: () => ref.read(shopSettingsProvider.notifier).refresh()),
      ),
      _ => const Scaffold(body: SplashView()),
    };
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.settings});

  final ShopSettings settings;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(categoriesProvider);
    await Future.wait([
      ref.read(shopSettingsProvider.notifier).refresh(),
      ref.read(productListProvider(const ProductFilter()).notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final client = ref.watch(clientConfigProvider);
    final isSignedIn = ref.watch(authControllerProvider).value != null;
    final delivery = settings.delivery;

    return Scaffold(
      bottomNavigationBar: const CartBar(),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(client.logoAsset, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
              title: Text(settings.shop.localizedName(locale)),
              actions: [
                const LanguageMenu(),
                if (isSignedIn)
                  IconButton(
                    key: const Key('myOrdersButton'),
                    tooltip: l10n.ordersTitle,
                    icon: const Icon(Icons.receipt_long_outlined),
                    onPressed: () => context.push(Routes.orders),
                  ),
                IconButton(
                  key: const Key('accountButton'),
                  tooltip: isSignedIn ? l10n.account : l10n.login,
                  icon: Icon(isSignedIn ? Icons.account_circle_outlined : Icons.login),
                  onPressed: () => context.push(isSignedIn ? Routes.account : Routes.login),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const Key('searchBox'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(Routes.search),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search, color: theme.colorScheme.outline),
                            const SizedBox(width: 8),
                            Text(l10n.searchHint, style: TextStyle(color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(l10n.welcome(settings.shop.localizedName(locale)), style: theme.textTheme.titleLarge),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  spacing: 8,
                  children: [
                    ActionChip(
                      key: const Key('shopInfoButton'),
                      avatar: const Icon(Icons.info_outline, size: 18),
                      label: Text(l10n.shopInfo),
                      onPressed: () => ShopInfoPanel.show(context, settings),
                    ),
                    if (delivery.enabled)
                      _InfoChip(icon: Icons.bolt_outlined, text: l10n.deliveryEta(delivery.etaMinutes))
                    else
                      _InfoChip(icon: Icons.storefront_outlined, text: l10n.deliveryUnavailable),
                    if (delivery.enabled && delivery.freeAbovePaise != null)
                      _InfoChip(
                        icon: Icons.local_offer_outlined,
                        text: l10n.deliveryFreeAbove(formatPaise(delivery.freeAbovePaise!)),
                      ),
                  ],
                ),
              ),
            ),
            if (settings.isEnabled(Feature.handwrittenListUpload) || settings.isEnabled(Feature.prescriptionUpload))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      key: const Key('listOrderButton'),
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(l10n.listOrderCta),
                      subtitle: Text(l10n.listOrderCtaSub),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        const target = '${Routes.checkout}?list=1';
                        final signedIn = ref.read(authControllerProvider).value != null;
                        context.push(signedIn ? target : '${Routes.login}?from=${Uri.encodeComponent(target)}');
                      },
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _Heading(l10n.categoriesTitle)),
            const SliverToBoxAdapter(child: CategoryStrip()),
            SliverToBoxAdapter(child: _Heading(l10n.allProducts)),
            const ProductGridSliver(ProductFilter()),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(icon, size: 18), label: Text(text));
}
