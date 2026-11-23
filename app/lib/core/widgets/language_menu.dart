import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../providers.dart';

/// App-bar language picker limited to the client's supported locales.
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

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
