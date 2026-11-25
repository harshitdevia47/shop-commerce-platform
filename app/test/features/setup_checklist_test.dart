import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/config/env_config.dart';
import 'package:qc_app/core/utils/launcher.dart';

import 'admin_catalog_test.dart' show pumpAdmin;

void main() {
  testWidgets('new owner sees what is left, each step opens the right place, and can hide it', (tester) async {
    // Fake shop: categories, a product and UPI exist; settings not saved yet, no rider, no orders.
    await pumpAdmin(tester, setupChecklist: true);

    expect(find.text('Get your shop ready'), findsOneWidget);
    expect(find.text('3 of 6 done'), findsOneWidget);
    expect(find.text('Set your UPI ID'), findsOneWidget);
    expect(find.text('Add a delivery person'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('setup-testOrder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-testOrder')));
    await tester.pumpAndSettle();
    expect(find.textContaining('log in with another mobile number'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('setup-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saveSettingsButton')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('hideSetupButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hideSetupButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setupChecklist')), findsNothing);
  });

  testWidgets('support opens WhatsApp with the shop name', (tester) async {
    final opened = <Uri>[];
    await pumpAdmin(
      tester,
      env: const EnvConfig(env: 'dev', apiBaseUrl: 'http://localhost', supportWhatsapp: '+91 90000 12345'),
      extraOverrides: [
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('supportButton')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('supportButton')));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), startsWith('https://wa.me/919000012345?text=Hello'));
    expect(opened.single.queryParameters['text'], 'Hello, I need help with the Sharma Kirana app.');
  });

  testWidgets('no support number configured: no support card', (tester) async {
    await pumpAdmin(tester);
    expect(find.byKey(const Key('supportButton')), findsNothing);
  });
}
