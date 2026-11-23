import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 0 home: proves the config pipeline end to end (build-time branding +
/// runtime shop settings + localization). Replaced by the catalog home in Phase 2.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final client = ref.watch(clientConfigProvider);
    final enabledFeatures = Feature.values.where(settings.isEnabled).toList();

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(client.logoAsset, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
        title: Text(settings.shop.localizedName(locale)),
        actions: const [_LanguageMenu()],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(shopSettingsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.welcome(settings.shop.localizedName(locale)),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _Section(title: l10n.deliveryTitle, children: _deliveryLines(l10n, settings.delivery)),
            const SizedBox(height: 12),
            _Section(
              title: l10n.paymentTitle,
              children: [
                if (settings.payments.cod) _Line(icon: Icons.payments_outlined, text: l10n.paymentCod),
                if (settings.payments.upiEnabled) _Line(icon: Icons.qr_code_2, text: l10n.paymentUpi),
              ],
            ),
            if (enabledFeatures.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: l10n.featuresTitle,
                children: [
                  for (final feature in enabledFeatures)
                    _Line(icon: Icons.check_circle_outline, text: feature.label(l10n)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _deliveryLines(AppLocalizations l10n, DeliveryRules delivery) {
    if (!delivery.enabled) return [_Line(icon: Icons.storefront_outlined, text: l10n.deliveryUnavailable)];
    return [
      _Line(icon: Icons.bolt_outlined, text: l10n.deliveryEta(delivery.etaMinutes)),
      if (delivery.minOrderPaise > 0)
        _Line(icon: Icons.shopping_basket_outlined, text: l10n.deliveryMinOrder(formatPaise(delivery.minOrderPaise))),
      if (delivery.feePaise > 0)
        _Line(icon: Icons.delivery_dining_outlined, text: l10n.deliveryFee(formatPaise(delivery.feePaise))),
      if (delivery.freeAbovePaise case final freeAbove?)
        _Line(icon: Icons.local_offer_outlined, text: l10n.deliveryFreeAbove(formatPaise(freeAbove))),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _LanguageMenu extends ConsumerWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientConfigProvider);
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.translate),
      tooltip: context.l10n.language,
      onSelected: (locale) => ref.read(localeProvider.notifier).set(locale),
      itemBuilder: (context) => [
        for (final locale in client.supportedLocales)
          PopupMenuItem(value: locale, child: Text(lookupAppLocalizations(locale).languageName)),
      ],
    );
  }
}
