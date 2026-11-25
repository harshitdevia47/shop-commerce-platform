import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/admin_catalog_repository.dart';
import 'admin_catalog_providers.dart';
import 'photo_picker.dart';

/// Fast entry at the counter: photo, name, size, price → "Save & next". The category stays selected
/// so a whole shelf goes in one after another. Everything else can be filled later in the full form.
class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _size = TextEditingController();
  final _price = TextEditingController();
  final _mrp = TextEditingController();
  final _stock = TextEditingController();
  final Map<String, TextEditingController> _axes = {};
  final _nameFocus = FocusNode();
  List<AttachedPhoto> _photos = const [];
  String? _categoryId;
  bool _saving = false;
  final List<String> _added = [];

  @override
  void dispose() {
    for (final c in [_name, _size, _price, _mrp, _stock, ..._axes.values]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  TextEditingController _axis(String axis) => _axes.putIfAbsent(axis, TextEditingController.new);

  Future<void> _save(CatalogSettings catalog) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final draft = ProductDraft(
      name: name,
      categoryId: _categoryId,
      imageMediaIds: [for (final p in _photos) p.id],
      variants: [
        VariantDraft(
          label: catalog.variantStyle == VariantStyle.units ? _size.text.trim() : '',
          options: catalog.variantStyle == VariantStyle.options
              ? {
                  for (final axis in catalog.variantAxes)
                    if (_axis(axis).text.trim().isNotEmpty) axis: _axis(axis).text.trim(),
                }
              : const {},
          pricePaise: parseRupees(_price.text)!,
          mrpPaise: _mrp.text.trim().isEmpty ? null : parseRupees(_mrp.text),
          stockQty: _stock.text.trim().isEmpty ? null : int.parse(_stock.text.trim()),
        ),
      ],
    );
    try {
      await ref.read(adminCatalogRepositoryProvider).createProduct(draft);
      ref.invalidate(adminProductListProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _added.insert(0, catalog.variantStyle == VariantStyle.units ? '$name · ${_size.text.trim()}' : name);
        _photos = const [];
        for (final c in [_name, _size, _price, _mrp, _stock, ..._axes.values]) {
          c.clear();
        }
      });
      _form.currentState!.reset();
      _nameFocus.requestFocus();
      messenger.showSnackBar(SnackBar(content: Text(l10n.quickAddSaved(name)), duration: const Duration(seconds: 2)));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final catalog = ref.watch(shopSettingsProvider).value?.catalog;
    final categories = ref.watch(adminCategoriesProvider).value ?? const <ProductCategory>[];
    final categoryIds = categories.map((c) => c.id).toSet();
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    InputDecoration deco(String label, {String? prefix}) =>
        InputDecoration(labelText: label, prefixText: prefix, border: const OutlineInputBorder(), isDense: true);

    if (catalog == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickAddTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: FilledButton.icon(
            key: const Key('quickSaveButton'),
            onPressed: _saving ? null : () => _save(catalog),
            icon: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.done_all),
            label: Text(l10n.quickAddSaveNext),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.quickAddHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('quickCategoryField'),
              initialValue: categoryIds.contains(_categoryId) ? _categoryId : null,
              decoration: deco(l10n.categoryLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noCategory)),
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.isTopLevel ? c.localizedName(locale) : '   ${c.localizedName(locale)}'),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            PhotoPicker(
              key: ValueKey('photos-${_added.length}'),
              photos: _photos,
              max: 1,
              onChanged: (photos) => setState(() => _photos = photos),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('quickNameField'),
              controller: _name,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: deco(l10n.nameEnglish),
              validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
            ),
            const SizedBox(height: 12),
            if (catalog.variantStyle == VariantStyle.units) ...[
              TextFormField(
                key: const Key('quickSizeField'),
                controller: _size,
                textInputAction: TextInputAction.next,
                decoration: deco(l10n.unitLabel),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
              ),
              const SizedBox(height: 12),
            ],
            if (catalog.variantStyle == VariantStyle.options) ...[
              Row(
                spacing: 8,
                children: [
                  for (final axis in catalog.variantAxes)
                    Expanded(
                      child: TextFormField(
                        key: Key('quickAxis-$axis'),
                        controller: _axis(axis),
                        decoration: deco(axis),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('quickPriceField'),
                    controller: _price,
                    inputFormatters: money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: deco(l10n.priceLabel, prefix: '₹ '),
                    validator: (v) => v == null || parseRupees(v) == null ? l10n.invalidPrice : null,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: const Key('quickMrpField'),
                    controller: _mrp,
                    inputFormatters: money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: deco(l10n.mrpLabel, prefix: '₹ '),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final mrp = parseRupees(v);
                      if (mrp == null) return l10n.invalidPrice;
                      final price = parseRupees(_price.text);
                      return price != null && mrp < price ? l10n.mrpBelowPrice : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('quickStockField'),
              controller: _stock,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              decoration: deco(l10n.stockLabel).copyWith(helperText: l10n.quickAddStockHint),
              onFieldSubmitted: (_) => _save(catalog),
            ),
            if (_added.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.quickAddCount(_added.length), style: theme.textTheme.titleSmall),
              for (final item in _added.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  title: Text(item),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
