import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_catalog_test.dart' show pumpAdmin;

void main() {
  testWidgets('quick add is on the products bar, saves and clears for the next product', (tester) async {
    final admin = await pumpAdmin(tester);
    await tester.tap(find.byKey(const Key('adminProductsTile')));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);
    expect(find.byTooltip('Import from Excel'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quickAddButton')));
    await tester.pumpAndSettle();

    // Required fields first.
    await tester.tap(find.byKey(const Key('quickSaveButton')));
    await tester.pumpAndSettle();
    expect(admin.created, isNull);

    await tester.tap(find.byKey(const Key('quickCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staples').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quickNameField')), 'Tata Salt');
    await tester.enterText(find.byKey(const Key('quickSizeField')), '1 kg');
    await tester.enterText(find.byKey(const Key('quickPriceField')), '28');
    await tester.enterText(find.byKey(const Key('quickStockField')), '60');
    await tester.tap(find.byKey(const Key('quickSaveButton')));
    await tester.pumpAndSettle();

    final draft = admin.created!;
    expect(draft.name, 'Tata Salt');
    expect(draft.categoryId, 'c1');
    expect(draft.variants.single.label, '1 kg');
    expect(draft.variants.single.pricePaise, 2800);
    expect(draft.variants.single.stockQty, 60);
    expect(find.text('Added now: 1'), findsOneWidget);
    expect(find.text('Tata Salt · 1 kg'), findsOneWidget);
    // Ready for the next one, same category.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: find.byKey(const Key('quickNameField')), matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '',
    );
    expect(find.text('Staples'), findsOneWidget);
  });
}
