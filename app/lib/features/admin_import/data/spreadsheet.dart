import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Thrown when a picked file cannot be read as a spreadsheet.
class SpreadsheetException implements Exception {
  const SpreadsheetException(this.reason);

  final String reason;

  @override
  String toString() => 'SpreadsheetException: $reason';
}

/// Reads an Excel (.xlsx, first sheet) or CSV file into rows of text cells, header first.
List<List<String>> readSpreadsheet(String fileName, Uint8List bytes) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.xlsx')) return _readXlsx(bytes);
  if (name.endsWith('.csv') || name.endsWith('.txt') || name.endsWith('.tsv')) {
    return parseCsv(utf8.decode(bytes, allowMalformed: true));
  }
  throw const SpreadsheetException('unsupported');
}

List<List<String>> _readXlsx(Uint8List bytes) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } on Object {
    throw const SpreadsheetException('unreadable');
  }
  final sheet = book.tables.values.where((s) => s.maxRows > 0).firstOrNull;
  if (sheet == null) return const [];
  return [
    for (final row in sheet.rows) [for (final cell in row) _cellText(cell?.value)],
  ];
}

String _cellText(CellValue? value) => switch (value) {
  null => '',
  // Excel keeps whole numbers as doubles: 110.0 -> "110".
  DoubleCellValue(:final value) when value == value.roundToDouble() && value.abs() < 1e12 => value.toInt().toString(),
  DoubleCellValue(:final value) => double.parse(value.toStringAsFixed(4)).toString(),
  TextCellValue() => value.toString(),
  _ => value.toString(),
}.trim();

/// RFC 4180 CSV (quoted cells, "" escapes, line breaks inside quotes). Excel in some languages
/// saves with `;`, and copied tables use tabs: the most common of `,` `;` tab in the first line wins.
List<List<String>> parseCsv(String text) {
  var input = text.startsWith('﻿') ? text.substring(1) : text; // Excel's UTF-8 BOM
  input = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final firstLine = input.split('\n').first;
  final delimiter = [
    ',',
    ';',
    '\t',
  ].reduce((best, d) => d.allMatches(firstLine).length > best.allMatches(firstLine).length ? d : best);

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == delimiter) {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (c == '\n') {
      row.add(cell.toString().trim());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString().trim());
    rows.add(row);
  }
  return rows;
}

/// Rows as CSV text (the template the owner opens in Excel or Google Sheets).
String toCsv(List<List<String>> rows) {
  String quote(String v) => RegExp(r'[",\n;]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
  // BOM so Excel opens Gujarati/Hindi text as UTF-8.
  return '﻿${rows.map((r) => r.map(quote).join(',')).join('\r\n')}\r\n';
}
