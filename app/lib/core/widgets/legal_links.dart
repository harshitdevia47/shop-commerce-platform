import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../utils/launcher.dart';

enum LegalPage { privacy, terms }

/// Public page on the server: `<API_BASE_URL>/legal/<slug>/privacy|terms` (also used in the Play listing).
Uri legalPageUri(WidgetRef ref, LegalPage page) {
  final base = Uri.parse(ref.read(envConfigProvider).apiBaseUrl);
  final slug = ref.read(clientConfigProvider).shopKey;
  return base.replace(path: '${base.path.replaceAll(RegExp(r'/$'), '')}/legal/$slug/${page.name}');
}

/// "Privacy policy · Terms of use", opened in the browser.
class LegalLinks extends ConsumerWidget {
  const LegalLinks({super.key, this.prefix});

  /// Optional sentence before the links, e.g. "By continuing you agree to".
  final String? prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    Future<void> open(LegalPage page) async {
      final messenger = ScaffoldMessenger.of(context);
      if (!await ref.read(externalLauncherProvider)(legalPageUri(ref, page))) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorNetwork)));
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix != null) Text(prefix!, style: small, textAlign: TextAlign.center),
        TextButton(
          key: const Key('privacyLink'),
          onPressed: () => open(LegalPage.privacy),
          child: Text(l10n.privacyPolicy),
        ),
        Text('·', style: small),
        TextButton(key: const Key('termsLink'), onPressed: () => open(LegalPage.terms), child: Text(l10n.termsOfUse)),
      ],
    );
  }
}
