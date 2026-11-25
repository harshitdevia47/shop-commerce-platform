import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin_catalog/presentation/admin_catalog_providers.dart';
import '../data/product_import_api.dart';
import '../data/spreadsheet.dart';

typedef PickedSheet = ({String name, Uint8List bytes});

/// Opens the phone's file chooser for an Excel/CSV file (overridden in tests).
final spreadsheetPickerProvider = Provider<Future<PickedSheet?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  },
);

/// Shares a file through the phone's share sheet (WhatsApp, Drive, email...). Overridden in tests.
final fileSharerProvider = Provider<Future<void> Function(String fileName, Uint8List bytes, String text)>(
  (ref) => (fileName, bytes, text) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: 'text/csv')],
        fileNameOverrides: [fileName],
        text: text,
      ),
    );
  },
);

enum _Stage { start, checking, preview, importing }

/// Owner/staff: add or update many products at once from an Excel or CSV file.
class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen> {
  _Stage _stage = _Stage.start;
  String? _fileName;
  List<List<String>>? _rows;
  ImportSummary? _summary;
  String? _problem;

  Future<void> _shareTemplate() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rows = await ref.read(productImportApiProvider).template();
      final bytes = Uint8List.fromList(utf8.encode(toCsv(rows)));
      await ref.read(fileSharerProvider)('products-template.csv', bytes, l10n.importTemplateShareText);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
  }

  Future<void> _pick() async {
    final l10n = context.l10n;
    final picked = await ref.read(spreadsheetPickerProvider)();
    if (picked == null || !mounted) return;
    setState(() {
      _stage = _Stage.checking;
      _fileName = picked.name;
      _summary = null;
      _problem = null;
    });
    try {
      final rows = readSpreadsheet(picked.name, picked.bytes);
      final summary = await ref.read(productImportApiProvider).run(rows, dryRun: true);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _summary = summary;
        _stage = _Stage.preview;
      });
    } on SpreadsheetException catch (error) {
      setState(() {
        _problem = error.reason == 'unsupported' ? l10n.importWrongFile : l10n.importUnreadable;
        _stage = _Stage.start;
      });
    } on Object catch (error) {
      setState(() {
        _problem = _fileProblem(l10n, error);
        _stage = _Stage.start;
      });
    }
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _stage = _Stage.importing);
    try {
      final done = await ref.read(productImportApiProvider).run(_rows!, dryRun: false);
      ref
        ..invalidate(adminProductListProvider)
        ..invalidate(adminCategoriesProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importDone(done.newProducts, done.updatedProducts))));
      navigator.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _problem = _fileProblem(l10n, error);
        _stage = _Stage.preview;
      });
    }
  }

  String _fileProblem(AppLocalizations l10n, Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'IMPORT_COLUMNS_MISSING':
          final missing = ((error.details as Map<String, dynamic>?)?['missing'] as List<dynamic>? ?? []).join(', ');
          return l10n.importColumnsMissing(missing);
        case 'IMPORT_EMPTY':
          return l10n.importEmpty;
        case 'IMPORT_TOO_LARGE':
          return l10n.importTooLarge;
        case 'IMPORT_INVALID':
          return l10n.importFixRows;
      }
    }
    return errorMessage(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final busy = _stage == _Stage.checking || _stage == _Stage.importing;
    final summary = _summary;
    final canImport = _stage == _Stage.preview && summary != null && summary.errorCount == 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      // The main action stays on screen: choose a file, then (when the check passed) import it.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: canImport || _stage == _Stage.importing
              ? FilledButton.icon(
                  key: const Key('confirmImportButton'),
                  onPressed: _stage == _Stage.importing ? null : _import,
                  icon: _stage == _Stage.importing
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(l10n.importConfirm(summary!.newProducts + summary.updatedProducts)),
                )
              : FilledButton.icon(
                  key: const Key('pickFileButton'),
                  onPressed: busy ? null : _pick,
                  icon: _stage == _Stage.checking
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_fileName == null ? l10n.importPickFile : l10n.importPickAnother),
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Text(l10n.importHowTitle, style: theme.textTheme.titleMedium),
                  _Step(number: 1, text: l10n.importStep1),
                  _Step(number: 2, text: l10n.importStep2),
                  _Step(number: 3, text: l10n.importStep3),
                  Text(l10n.importRules, style: theme.textTheme.bodySmall),
                  OutlinedButton.icon(
                    key: const Key('shareTemplateButton'),
                    onPressed: busy ? null : _shareTemplate,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.importGetTemplate),
                  ),
                ],
              ),
            ),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(l10n.importFile(_fileName!), style: theme.textTheme.bodySmall)),
                if (canImport)
                  TextButton(
                    key: const Key('pickAnotherButton'),
                    onPressed: _pick,
                    child: Text(l10n.importPickAnother),
                  ),
              ],
            ),
          ],
          if (_problem != null) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('importProblem'),
              color: theme.colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_problem!)),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 16),
            _SummaryCard(summary: summary),
            if (summary.errorCount > 0) ...[
              const SizedBox(height: 16),
              Text(l10n.importErrorsTitle(summary.errorCount), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.importErrorsHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final e in summary.errors)
                ListTile(
                  key: ValueKey('importError-${e.row}-${e.code}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.errorContainer,
                    child: Text('${e.row}', style: theme.textTheme.labelMedium),
                  ),
                  title: Text(_rowErrorText(l10n, e.code)),
                  subtitle: Text(
                    e.column == null ? l10n.importRowLabel(e.row) : l10n.importRowColumnLabel(e.row, e.column!),
                  ),
                ),
              if (summary.errorCount > summary.errors.length)
                Text(l10n.importMoreErrors(summary.errorCount - summary.errors.length)),
            ],
          ],
        ],
      ),
    );
  }
}

String _rowErrorText(AppLocalizations l10n, String code) => switch (code) {
  'NAME_REQUIRED' => l10n.importErrNameRequired,
  'NAME_TOO_LONG' => l10n.importErrNameTooLong,
  'PRICE_INVALID' => l10n.importErrPrice,
  'MRP_INVALID' => l10n.importErrMrp,
  'MRP_BELOW_PRICE' => l10n.importErrMrpBelow,
  'STOCK_INVALID' => l10n.importErrStock,
  'SIZE_REQUIRED' => l10n.importErrSize,
  'OPTION_REQUIRED' => l10n.importErrOption,
  'DUPLICATE_ROW' => l10n.importErrDuplicateRow,
  'DUPLICATE_PRODUCT' => l10n.importErrDuplicateProduct,
  'TOO_MANY_VARIANTS' => l10n.importErrTooManyVariants,
  'FIELD_INVALID' => l10n.importErrField,
  'FIELD_REQUIRED' => l10n.importErrFieldRequired,
  _ => l10n.importErrOther,
};

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: [
      CircleAvatar(radius: 12, child: Text('$number', style: Theme.of(context).textTheme.labelSmall)),
      Expanded(child: Text(text)),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = summary.errorCount == 0;
    return Card(
      key: const Key('importSummary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(
                  ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: ok ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                ),
                Expanded(
                  child: Text(
                    ok ? l10n.importReady(summary.rows) : l10n.importNotReady,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(l10n.importNewProducts(summary.newProducts, summary.newVariants)),
            Text(l10n.importUpdatedProducts(summary.updatedProducts, summary.updatedVariants)),
            if (summary.newCategories.isNotEmpty) Text(l10n.importNewCategories(summary.newCategories.join(', '))),
            if (summary.ignoredColumns.isNotEmpty) Text(l10n.importIgnoredColumns(summary.ignoredColumns.join(', '))),
            Text(l10n.importPhotosNote, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
