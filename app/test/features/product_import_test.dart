import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/features/admin_import/data/product_import_api.dart';
import 'package:qc_app/features/admin_import/data/spreadsheet.dart';
import 'package:qc_app/features/admin_import/presentation/product_import_screen.dart';

import 'admin_catalog_test.dart' show pumpAdmin;

class FakeImportApi implements ProductImportApi {
  final runs = <(List<List<String>>, bool)>[];
  List<ImportRowError> errors = const [];

  @override
  Future<List<List<String>>> template() async => [
    ['category', 'name', 'size', 'price'],
    ['Rice', 'Basmati Rice', '1 kg', '110'],
  ];

  @override
  Future<ImportSummary> run(List<List<String>> rows, {required bool dryRun}) async {
    runs.add((rows, dryRun));
    if (rows.first.length < 2) {
      throw const ApiException(
        'IMPORT_COLUMNS_MISSING',
        'x',
        details: {
          'missing': ['price'],
        },
      );
    }
    return ImportSummary(
      rows: rows.length - 1,
      newProducts: 2,
      updatedProducts: 1,
      newVariants: 3,
      updatedVariants: 1,
      newCategories: const ['Rice'],
      ignoredColumns: const ['Notes'],
      errors: errors,
      errorCount: errors.length,
      imported: !dryRun,
    );
  }
}

Future<void> pick(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pickFileButton')));
  await tester.pumpAndSettle();
}

Future<void> see(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
  expect(finder, findsOneWidget);
}

Uint8List csvBytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('reading files', () {
    test('CSV with quotes, Excel BOM, semicolons and blank lines', () {
      expect(parseCsv('﻿name,price\r\n"Rice, Basmati",110\r\n"Say ""hi""",5\r\n'), [
        ['name', 'price'],
        ['Rice, Basmati', '110'],
        ['Say "hi"', '5'],
      ]);
      expect(parseCsv('name;price\nDal;90'), [
        ['name', 'price'],
        ['Dal', '90'],
      ]);
      expect(
        parseCsv(
          toCsv([
            ['name', 'note'],
            ['Tea', 'a,b'],
          ]),
        ).last,
        ['Tea', 'a,b'],
      );
    });

    test('Excel: first sheet, whole numbers without .0', () {
      final book = Excel.createExcel();
      final sheet = book[book.getDefaultSheet()!];
      sheet.appendRow([TextCellValue('name'), TextCellValue('price'), TextCellValue('stock')]);
      sheet.appendRow([TextCellValue('Basmati Rice'), const DoubleCellValue(110), const IntCellValue(40)]);
      sheet.appendRow([TextCellValue('Ghee'), const DoubleCellValue(1250.5), TextCellValue('')]);
      final rows = readSpreadsheet('products.xlsx', Uint8List.fromList(book.save()!));
      expect(rows[1], ['Basmati Rice', '110', '40']);
      expect(rows[2], ['Ghee', '1250.5', '']);
      expect(() => readSpreadsheet('photo.jpg', Uint8List(3)), throwsA(isA<SpreadsheetException>()));
    });
  });

  testWidgets('owner shares the template, checks a file, sees the preview and imports', (tester) async {
    final api = FakeImportApi();
    final shared = <String>[];
    await pumpAdmin(
      tester,
      extraOverrides: [
        productImportApiProvider.overrideWithValue(api),
        fileSharerProvider.overrideWithValue((name, bytes, text) async => shared.add('$name:${utf8.decode(bytes)}')),
        spreadsheetPickerProvider.overrideWithValue(
          () async => (name: 'my-shop.csv', bytes: csvBytes('name,size,price,Notes\nBasmati Rice,1 kg,110,x\n')),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('adminProductsTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importProductsButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('shareTemplateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shareTemplateButton')));
    await tester.pumpAndSettle();
    expect(shared.single, startsWith('products-template.csv:'));
    expect(shared.single, contains('category,name,size,price\r\nRice,Basmati Rice,1 kg,110\r\n'));

    await pick(tester);
    expect(api.runs.single.$2, isTrue); // checked first, nothing saved
    expect(api.runs.single.$1[1], ['Basmati Rice', '1 kg', '110', 'x']);
    await see(tester, find.text('Ready to import 1 rows'));
    await see(tester, find.text('New categories: Rice'));
    await see(tester, find.text('Not imported (unknown columns): Notes'));

    await tester.tap(find.byKey(const Key('confirmImportButton')));
    await tester.pumpAndSettle();
    expect(api.runs.last.$2, isFalse);
    expect(find.text('Done: 2 added, 1 updated'), findsOneWidget);
    expect(find.byKey(const Key('importProductsButton')), findsOneWidget); // back on the product list
  });

  testWidgets('row problems are listed with row and column, and import is not offered', (tester) async {
    final api = FakeImportApi()
      ..errors = const [
        ImportRowError(row: 3, code: 'PRICE_INVALID', column: 'Price'),
        ImportRowError(row: 7, code: 'DUPLICATE_ROW'),
      ];
    await pumpAdmin(
      tester,
      extraOverrides: [
        productImportApiProvider.overrideWithValue(api),
        spreadsheetPickerProvider.overrideWithValue(() async => (name: 'a.csv', bytes: csvBytes('name,price\nx,1'))),
      ],
    );
    await tester.tap(find.byKey(const Key('adminProductsTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importProductsButton')));
    await tester.pumpAndSettle();
    await pick(tester);

    await see(tester, find.text('2 problems'));
    await see(tester, find.text('Price must be a number like 120 or 120.50'));
    await see(tester, find.text('Row 3 · column Price'));
    await see(tester, find.text('Same product and size appears twice'));
    expect(find.byKey(const Key('confirmImportButton')), findsNothing);
  });

  testWidgets('wrong files and missing columns are explained', (tester) async {
    final api = FakeImportApi();
    var file = (name: 'photo.jpg', bytes: Uint8List(4));
    await pumpAdmin(
      tester,
      extraOverrides: [
        productImportApiProvider.overrideWithValue(api),
        spreadsheetPickerProvider.overrideWithValue(() async => file),
      ],
    );
    await tester.tap(find.byKey(const Key('adminProductsTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importProductsButton')));
    await tester.pumpAndSettle();

    await pick(tester);
    await see(tester, find.textContaining('Choose an Excel (.xlsx) or CSV file'));

    file = (name: 'items.csv', bytes: csvBytes('item\nRice'));
    await pick(tester);
    await see(tester, find.text('These columns are missing in the first row: price. Use the template.'));
  });
}
