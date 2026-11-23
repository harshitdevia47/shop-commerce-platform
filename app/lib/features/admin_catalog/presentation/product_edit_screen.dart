import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/admin_catalog_repository.dart';
import 'admin_catalog_providers.dart';
import 'photo_picker.dart';

/// Add (productId == null) or edit a product. The form adapts to the shop's variant style and custom fields.
class ProductEditScreen extends ConsumerWidget {
  const ProductEditScreen({this.productId, super.key});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(shopSettingsProvider).value;
    final id = productId;
    final product = id == null ? null : ref.watch(adminProductProvider(id));
    final title = Text(id == null ? l10n.addProduct : l10n.editProduct);

    if (settings == null) return Scaffold(appBar: AppBar(title: title), body: const SplashView());
    return switch (product) {
      null => _ProductForm(catalog: settings.catalog, product: null),
      AsyncValue(:final value?) => _ProductForm(key: ValueKey(value.id), catalog: settings.catalog, product: value),
      AsyncValue(:final error?) => Scaffold(
        appBar: AppBar(title: title),
        body: ErrorView(error: error, onRetry: () => ref.invalidate(adminProductProvider(id!))),
      ),
      _ => Scaffold(appBar: AppBar(title: title), body: const SplashView()),
    };
  }
}

/// Editable state of one variant row.
class _VariantRow {
  _VariantRow({required List<String> axes, Variant? variant})
    : id = variant?.id,
      label = TextEditingController(text: variant?.label ?? ''),
      price = TextEditingController(text: variant == null ? '' : paiseToInput(variant.pricePaise)),
      mrp = TextEditingController(text: variant?.mrpPaise == null ? '' : paiseToInput(variant!.mrpPaise!)),
      stock = TextEditingController(text: variant?.stockQty?.toString() ?? ''),
      isAvailable = variant?.isAvailable ?? true,
      options = {for (final axis in axes) axis: TextEditingController(text: variant?.options[axis] ?? '')};

  final String? id;
  final TextEditingController label;
  final TextEditingController price;
  final TextEditingController mrp;
  final TextEditingController stock;
  final Map<String, TextEditingController> options;
  bool isAvailable;

  VariantDraft toDraft() => VariantDraft(
    id: id,
    label: label.text.trim(),
    options: {
      for (final entry in options.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
    },
    pricePaise: parseRupees(price.text)!,
    mrpPaise: mrp.text.trim().isEmpty ? null : parseRupees(mrp.text),
    stockQty: stock.text.trim().isEmpty ? null : int.parse(stock.text.trim()),
    isAvailable: isAvailable,
  );

  void dispose() {
    for (final c in [label, price, mrp, stock, ...options.values]) {
      c.dispose();
    }
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.catalog, required this.product, super.key});

  final CatalogSettings catalog;
  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _nameGu = TextEditingController(text: widget.product?.nameI18n?['gu']);
  late final _nameHi = TextEditingController(text: widget.product?.nameI18n?['hi']);
  late final _description = TextEditingController(text: widget.product?.description);
  late final _tags = TextEditingController(text: widget.product?.tags.join(', '));
  late final Map<String, TextEditingController> _customText = {
    for (final field in widget.catalog.customFields)
      if (field.type == CustomFieldType.text || field.type == CustomFieldType.number)
        field.key: TextEditingController(text: widget.product?.customFields[field.key]?.toString()),
  };
  late final Map<String, Object?> _customValues = {
    for (final field in widget.catalog.customFields)
      if (field.type == CustomFieldType.boolean || field.type == CustomFieldType.select)
        field.key: widget.product?.customFields[field.key],
  };
  late String? _categoryId = widget.product?.categoryId;
  late bool _isActive = widget.product?.isActive ?? true;
  late List<AttachedPhoto> _photos = [
    for (final image in widget.product?.images ?? const <ProductImage>[]) (id: image.mediaId, thumbUrl: image.thumbUrl),
  ];
  late final List<_VariantRow> _variants = [
    for (final variant in widget.product?.variants ?? const <Variant>[]) _VariantRow(axes: _axes, variant: variant),
    if (widget.product == null) _VariantRow(axes: _axes),
  ];
  bool _saving = false;

  List<String> get _axes => widget.catalog.variantStyle == VariantStyle.options ? widget.catalog.variantAxes : const [];

  @override
  void dispose() {
    for (final c in [_name, _nameGu, _nameHi, _description, _tags, ..._customText.values]) {
      c.dispose();
    }
    for (final row in _variants) {
      row.dispose();
    }
    super.dispose();
  }

  ProductDraft _draft() {
    final custom = <String, Object>{};
    for (final field in widget.catalog.customFields) {
      final value = switch (field.type) {
        CustomFieldType.text => _customText[field.key]!.text.trim(),
        CustomFieldType.number => num.tryParse(_customText[field.key]!.text.trim()),
        CustomFieldType.boolean || CustomFieldType.select => _customValues[field.key],
      };
      if (value != null && value != '') custom[field.key] = value;
    }
    return ProductDraft(
      name: _name.text.trim(),
      nameI18n: {
        if (_nameGu.text.trim().isNotEmpty) 'gu': _nameGu.text.trim(),
        if (_nameHi.text.trim().isNotEmpty) 'hi': _nameHi.text.trim(),
      },
      description: _description.text.trim(),
      categoryId: _categoryId,
      customFields: custom,
      tags: [for (final t in _tags.text.split(',')) if (t.trim().isNotEmpty) t.trim()],
      imageMediaIds: [for (final p in _photos) p.id],
      isActive: _isActive,
      variants: [for (final row in _variants) row.toDraft()],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = ref.read(adminCatalogRepositoryProvider);
    try {
      final id = widget.product?.id;
      if (id == null) {
        await repository.createProduct(_draft());
      } else {
        await repository.replaceProduct(id, _draft());
      }
      if (!mounted) return;
      invalidateCatalog(ref);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saved)));
      context.pop();
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteProductConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(adminCatalogRepositoryProvider).deleteProduct(widget.product!.id);
      if (!mounted) return;
      invalidateCatalog(ref);
      context.pop();
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final style = widget.catalog.variantStyle;
    final categories = ref.watch(adminCategoriesProvider).value ?? const <ProductCategory>[];
    final categoryIds = categories.map((c) => c.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? l10n.addProduct : l10n.editProduct),
        actions: [
          if (widget.product != null)
            IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : _delete),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            key: const Key('saveProductButton'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.photos, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            PhotoPicker(photos: _photos, onChanged: (photos) => setState(() => _photos = photos)),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('productNameField'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.nameEnglish, border: const OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameGu,
              decoration: InputDecoration(labelText: l10n.nameGujarati, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameHi,
              decoration: InputDecoration(labelText: l10n.nameHindi, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: categoryIds.contains(_categoryId) ? _categoryId : null,
              decoration: InputDecoration(labelText: l10n.categoryLabel, border: const OutlineInputBorder()),
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
            const SizedBox(height: 24),
            Text(
              switch (style) {
                VariantStyle.single => l10n.pricesTitle,
                VariantStyle.units => l10n.unitsTitle,
                VariantStyle.options => l10n.optionsTitle,
              },
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final (index, row) in _variants.indexed)
              _VariantEditor(
                key: ObjectKey(row),
                index: index,
                row: row,
                style: style,
                axes: _axes,
                l10n: l10n,
                onRemove: _variants.length > 1 ? () => setState(() => _variants.removeAt(index).dispose()) : null,
                onChanged: () => setState(() {}),
              ),
            if (style != VariantStyle.single)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('addVariantButton'),
                  onPressed: () => setState(() => _variants.add(_VariantRow(axes: _axes))),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addVariant),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.visibleToCustomers),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.moreDetails),
              initiallyExpanded: widget.catalog.customFields.any((f) => f.required),
              childrenPadding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final field in widget.catalog.customFields) ...[
                  _customFieldInput(field, locale, l10n),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(labelText: l10n.descriptionLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  decoration: InputDecoration(labelText: l10n.tagsLabel, border: const OutlineInputBorder()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customFieldInput(CustomFieldDef field, Locale locale, AppLocalizations l10n) {
    final label = field.localizedLabel(locale);
    String? required(String? v) => field.required && (v == null || v.trim().isEmpty) ? l10n.requiredField : null;
    return switch (field.type) {
      CustomFieldType.text => TextFormField(
        controller: _customText[field.key],
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required,
      ),
      CustomFieldType.number => TextFormField(
        controller: _customText[field.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) => required(v) ?? (v != null && v.trim().isNotEmpty && num.tryParse(v.trim()) == null ? l10n.invalidPrice : null),
      ),
      CustomFieldType.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _customValues[field.key] == true,
        onChanged: (value) => setState(() => _customValues[field.key] = value),
      ),
      CustomFieldType.select => DropdownButtonFormField<String?>(
        initialValue: _customValues[field.key] as String?,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          if (!field.required) const DropdownMenuItem(value: null, child: Text('—')),
          for (final option in field.options) DropdownMenuItem(value: option, child: Text(option)),
        ],
        validator: (v) => field.required && v == null ? l10n.requiredField : null,
        onChanged: (value) => setState(() => _customValues[field.key] = value),
      ),
    };
  }
}

class _VariantEditor extends StatelessWidget {
  const _VariantEditor({
    required this.index,
    required this.row,
    required this.style,
    required this.axes,
    required this.l10n,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final int index;
  final _VariantRow row;
  final VariantStyle style;
  final List<String> axes;
  final AppLocalizations l10n;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  static final _digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true);
    String? priceValidator(String? v) => v == null || parseRupees(v) == null ? l10n.invalidPrice : null;
    String? mrpValidator(String? v) {
      if (v == null || v.trim().isEmpty) return null;
      final mrp = parseRupees(v);
      if (mrp == null) return l10n.invalidPrice;
      final price = parseRupees(row.price.text);
      return price != null && mrp < price ? l10n.mrpBelowPrice : null;
    }

    final fields = <Widget>[
      if (style == VariantStyle.units)
        TextFormField(
          key: Key('variantLabel-$index'),
          controller: row.label,
          decoration: deco(l10n.unitLabel),
          validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
        ),
      if (style == VariantStyle.options)
        Row(
          spacing: 8,
          children: [
            for (final axis in axes)
              Expanded(
                child: TextFormField(
                  key: Key('variantOption-$index-$axis'),
                  controller: row.options[axis],
                  decoration: deco(axisLabel(l10n, axis)),
                  validator: axis == axes.first
                      ? (_) => row.options.values.every((c) => c.text.trim().isEmpty) ? l10n.requiredField : null
                      : null,
                ),
              ),
          ],
        ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            child: TextFormField(
              key: Key('variantPrice-$index'),
              controller: row.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _digits,
              decoration: deco(l10n.priceLabel),
              validator: priceValidator,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: row.mrp,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _digits,
              decoration: deco(l10n.mrpLabel),
              validator: mrpValidator,
            ),
          ),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            child: TextFormField(
              controller: row.stock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: deco(l10n.stockLabel),
            ),
          ),
          Expanded(
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inStockLabel),
              value: row.isAvailable,
              onChanged: (value) {
                row.isAvailable = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(spacing: 12, children: fields)),
            if (onRemove != null) IconButton(tooltip: l10n.remove, icon: const Icon(Icons.delete_outline), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}
