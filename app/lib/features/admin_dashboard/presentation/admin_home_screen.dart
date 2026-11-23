import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../auth/presentation/auth_controller.dart';

/// OWNER/STAFF landing page. Orders, products and sales arrive in Phases 2–3.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).value;
    final shopName = ref.watch(shopSettingsProvider).value?.shop.localizedName(ref.watch(localeProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(shopName ?? l10n.adminTitle),
        actions: [
          IconButton(
            tooltip: l10n.account,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.account),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.adminTitle, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(l10n.adminWelcome(user?.name ?? user?.phone ?? ''), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              key: const Key('adminOrdersTile'),
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.adminOrders),
              subtitle: Text(l10n.adminOrdersSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.adminOrders),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('adminProductsTile'),
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l10n.adminProducts),
              subtitle: Text(l10n.adminProductsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.adminProducts),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('adminCategoriesTile'),
              leading: const Icon(Icons.category_outlined),
              title: Text(l10n.adminCategories),
              subtitle: Text(l10n.adminCategoriesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.adminCategories),
            ),
          ),
        ],
      ),
    );
  }
}
