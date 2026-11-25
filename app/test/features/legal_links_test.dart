import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/utils/launcher.dart';

import 'admin_catalog_test.dart' show pumpAdmin;

void main() {
  testWidgets('account screen opens this shop privacy policy and terms in the browser', (tester) async {
    final opened = <Uri>[];
    await pumpAdmin(
      tester,
      extraOverrides: [
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('termsLink')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('privacyLink')));
    await tester.tap(find.byKey(const Key('termsLink')));
    await tester.pumpAndSettle();
    expect(opened.map((u) => u.toString()), [
      'http://localhost/legal/sharma_kirana/privacy',
      'http://localhost/legal/sharma_kirana/terms',
    ]);
  });
}
