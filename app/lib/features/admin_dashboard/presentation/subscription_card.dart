import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/money.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';

/// The shop's subscription to the platform, on the dashboard: a reminder for the owner when it is
/// due, and for everyone in the shop when the platform paused online orders. Hidden when all is well.
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sub = ref.watch(shopSettingsProvider).value?.subscription;
    final isOwner = ref.watch(authControllerProvider).value?.role == UserRole.owner;
    if (sub == null || sub.state == SubscriptionState.ok) return const SizedBox.shrink();
    if (sub.state == SubscriptionState.due && !isOwner) return const SizedBox.shrink();

    final amount = formatPaise(sub.amountPaise ?? 0);
    final paused = sub.state == SubscriptionState.paused;
    final date = sub.dueDate == null ? '' : DateFormat('d MMM y', Localizations.localeOf(context).languageCode).format(sub.dueDate!);
    final title = paused ? l10n.subscriptionPausedTitle : l10n.subscriptionDueTitle(amount, date);
    final body = paused ? l10n.subscriptionPausedBody(amount) : (sub.payTo == null ? l10n.subscriptionPayNoUpi : l10n.subscriptionPayTo(sub.payTo!));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: const Key('subscriptionCard'),
        color: paused ? theme.colorScheme.errorContainer : theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Icon(paused ? Icons.pause_circle_outline : Icons.receipt_long_outlined),
                  Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ],
              ),
              Text(body),
              if (isOwner && sub.payTo != null && sub.amountPaise != null)
                FilledButton.icon(
                  key: const Key('subscriptionPayButton'),
                  onPressed: () => ref.read(externalLauncherProvider)(
                    Uri(
                      scheme: 'upi',
                      host: 'pay',
                      queryParameters: {
                        'pa': sub.payTo!,
                        'pn': 'Shop app subscription',
                        'am': (sub.amountPaise! / 100).toStringAsFixed(2),
                        'cu': 'INR',
                        'tn': '${ref.read(shopSettingsProvider).value?.slug ?? ''} subscription',
                      },
                    ),
                  ),
                  icon: const Icon(Icons.currency_rupee),
                  label: Text(l10n.subscriptionPayButton),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
