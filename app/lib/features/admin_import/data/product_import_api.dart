import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';

/// One problem in the owner's file.
class ImportRowError {
  const ImportRowError({required this.row, required this.code, this.column});

  factory ImportRowError.fromJson(Map<String, dynamic> json) =>
      ImportRowError(row: json['row'] as int, code: json['code'] as String, column: json['column'] as String?);

  /// Spreadsheet row number (header = 1).
  final int row;
  final String code;
  final String? column;
}

class ImportSummary {
  const ImportSummary({
    required this.rows,
    required this.newProducts,
    required this.updatedProducts,
    required this.newVariants,
    required this.updatedVariants,
    required this.newCategories,
    required this.ignoredColumns,
    required this.errors,
    required this.errorCount,
    required this.imported,
  });

  factory ImportSummary.fromJson(Map<String, dynamic> json) => ImportSummary(
    rows: json['rows'] as int,
    newProducts: json['newProducts'] as int,
    updatedProducts: json['updatedProducts'] as int,
    newVariants: json['newVariants'] as int,
    updatedVariants: json['updatedVariants'] as int,
    newCategories: (json['newCategories'] as List<dynamic>).cast<String>(),
    ignoredColumns: (json['ignoredColumns'] as List<dynamic>).cast<String>(),
    errors: [for (final e in json['errors'] as List<dynamic>) ImportRowError.fromJson(e as Map<String, dynamic>)],
    errorCount: json['errorCount'] as int,
    imported: json['imported'] as bool,
  );

  final int rows;
  final int newProducts;
  final int updatedProducts;
  final int newVariants;
  final int updatedVariants;
  final List<String> newCategories;
  final List<String> ignoredColumns;
  final List<ImportRowError> errors;
  final int errorCount;
  final bool imported;
}

abstract interface class ProductImportApi {
  /// This shop's columns and two example rows.
  Future<List<List<String>>> template();

  /// [dryRun]: check only. A real run with problems throws [ApiException] `IMPORT_INVALID`.
  Future<ImportSummary> run(List<List<String>> rows, {required bool dryRun});
}

class HttpProductImportApi implements ProductImportApi {
  HttpProductImportApi(this._dio);

  final Dio _dio;

  @override
  Future<List<List<String>>> template() async {
    final json = await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/admin/catalog/import/template'));
    return [
      (json['columns'] as List<dynamic>).cast<String>(),
      for (final row in json['rows'] as List<dynamic>) (row as List<dynamic>).cast<String>(),
    ];
  }

  @override
  Future<ImportSummary> run(List<List<String>> rows, {required bool dryRun}) async => ImportSummary.fromJson(
    await unwrap<Map<String, dynamic>>(
      _dio.post<dynamic>('/api/v1/admin/catalog/import', data: {'rows': rows, 'dryRun': dryRun}),
    ),
  );
}

final productImportApiProvider = Provider<ProductImportApi>((ref) => HttpProductImportApi(ref.watch(dioProvider)));
