import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/launcher.dart';
import '../../admin_catalog/presentation/admin_catalog_providers.dart';
import '../../delivery/presentation/delivery_providers.dart';
import '../../orders/presentation/orders_providers.dart';

/// First-time setup for a new shop owner, in the order that makes the shop ready to sell.
enum SetupStep { categories, products, payments, settings, rider, testOrder }

class SetupProgress {
  const SetupProgress({required this.steps, required this.hidden});

  /// Step → done. Steps that do not apply (rider when the shop has no delivery) are left out.
  final Map<SetupStep, bool> steps;
  final bool hidden;

  int get doneCount => steps.values.where((done) => done).length;
  bool get allDone => doneCount == steps.length;
}

String _settingsKey(String shopId) => 'setup_settings_reviewed_$shopId';
String _hiddenKey(String shopId) => 'setup_hidden_$shopId';

/// Called when the owner saves Shop settings (the "check delivery and timings" step).
Future<void> markSettingsReviewed(WidgetRef ref) async {
  final shopId = ref.read(shopSettingsProvider).value?.id;
  if (shopId == null) return;
  try {
    await ref.read(sharedPreferencesProvider).setBool(_settingsKey(shopId), true);
  } on Object {
    // Only a convenience: the step stays open.
  }
  ref.invalidate(setupChecklistProvider);
}

/// Each step is read from real data (categories, products, payments, riders, orders), so it ticks
/// itself; only "settings reviewed" and "hidden" are remembered on the phone.
final setupChecklistProvider = FutureProvider.autoDispose<SetupProgress>((ref) async {
  final settings = await ref.watch(shopSettingsProvider.future);
  final prefs = ref.read(sharedPreferencesProvider);
  final catalog = ref.read(adminCatalogRepositoryProvider);
  final orders = ref.read(adminOrdersRepositoryProvider);

  Future<bool> check(Future<bool> Function() fn) async {
    try {
      return await fn();
    } on Object {
      return false; // offline or not allowed: show as not done, never fail the dashboard
    }
  }

  final delivery = settings.delivery.enabled;
  final results = await Future.wait([
    check(() async => (await catalog.categories()).isNotEmpty),
    check(() async => (await catalog.products()).items.isNotEmpty),
    if (delivery) check(() async => (await ref.read(teamRepositoryProvider).members()).any((m) => m.role == 'RIDER')),
    check(() async {
      for (final group in ['done', 'active', 'new']) {
        if ((await orders.orders(group: group)).items.isNotEmpty) return true;
      }
      return false;
    }),
  ]);
  var i = 0;
  return SetupProgress(
    steps: {
      SetupStep.categories: results[i++],
      SetupStep.products: results[i++],
      SetupStep.payments: settings.payments.upiEnabled || settings.payments.razorpayEnabled,
      SetupStep.settings: prefs.getBool(_settingsKey(settings.id)) ?? false,
      if (delivery) SetupStep.rider: results[i++],
      SetupStep.testOrder: results[i++],
    },
    hidden: prefs.getBool(_hiddenKey(settings.id)) ?? false,
  );
});

/// Dashboard card: "Get your shop ready", progress, each step opens the right screen.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, SetupStep step) async {
    final l10n = context.l10n;
    final route = switch (step) {
      SetupStep.categories => Routes.adminCategories,
      SetupStep.products => Routes.adminProducts,
      SetupStep.payments || SetupStep.settings => Routes.adminSettings,
      SetupStep.rider => Routes.adminTeam,
      SetupStep.testOrder => null,
    };
    if (route == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.setupTestOrder),
          content: Text(l10n.setupTestOrderHow),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.setupGotIt))],
        ),
      );
    } else {
      await context.push(route);
    }
    ref.invalidate(setupChecklistProvider);
  }

  Future<void> _hide(WidgetRef ref) async {
    final shopId = ref.read(shopSettingsProvider).value?.id;
    if (shopId == null) return;
    try {
      await ref.read(sharedPreferencesProvider).setBool(_hiddenKey(shopId), true);
    } on Object {
      // ignore: the card just stays
    }
    ref.invalidate(setupChecklistProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final progress = ref.watch(setupChecklistProvider).value;
    if (progress == null || progress.hidden) return const SizedBox.shrink();

    String title(SetupStep step) => switch (step) {
      SetupStep.categories => l10n.setupCategories,
      SetupStep.products => l10n.setupProducts,
      SetupStep.payments => l10n.setupPayments,
      SetupStep.settings => l10n.setupSettings,
      SetupStep.rider => l10n.setupRider,
      SetupStep.testOrder => l10n.setupTestOrder,
    };
    String hint(SetupStep step) => switch (step) {
      SetupStep.categories => l10n.setupCategoriesHint,
      SetupStep.products => l10n.setupProductsHint,
      SetupStep.payments => l10n.setupPaymentsHint,
      SetupStep.settings => l10n.setupSettingsHint,
      SetupStep.rider => l10n.setupRiderHint,
      SetupStep.testOrder => l10n.setupTestOrderHint,
    };

    return Card(
      key: const Key('setupChecklist'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.allDone ? l10n.setupAllDone : l10n.setupTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(key: const Key('hideSetupButton'), onPressed: () => _hide(ref), child: Text(l10n.setupHide)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(l10n.setupProgress(progress.doneCount, progress.steps.length)),
                  LinearProgressIndicator(
                    value: progress.doneCount / progress.steps.length,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final MapEntry(key: step, value: done) in progress.steps.entries)
              ListTile(
                key: ValueKey('setup-${step.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                title: Text(title(step), style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                subtitle: done ? null : Text(hint(step)),
                trailing: done ? null : const Icon(Icons.chevron_right),
                onTap: done ? null : () => _open(context, ref, step),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Need help?" card: WhatsApp chat with the platform team, prefilled with the shop name.
class SupportCard extends ConsumerWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final number = ref.watch(envConfigProvider).supportWhatsapp;
    if (number == null) return const SizedBox.shrink();
    final shop = ref.watch(shopSettingsProvider).value?.shop.name ?? '';
    return Card(
      child: ListTile(
        key: const Key('supportButton'),
        leading: const Icon(Icons.support_agent),
        title: Text(l10n.supportTitle),
        subtitle: Text(l10n.supportSubtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final uri = Uri.https('wa.me', '/${number.replaceAll(RegExp(r'\D'), '')}', {
            'text': l10n.supportMessage(shop),
          });
          final opened = await ref.read(externalLauncherProvider)(uri);
          if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.supportNoWhatsapp(number))));
        },
      ),
    );
  }
}
