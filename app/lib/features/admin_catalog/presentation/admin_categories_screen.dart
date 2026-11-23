import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/server_image.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/admin_catalog_repository.dart';
import 'admin_catalog_providers.dart';
import 'photo_picker.dart';

/// Two-level category tree: add, rename, translate, hide, delete.
class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final categories = ref.watch(adminCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminCategories)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addCategoryButton'),
        onPressed: () => CategoryEditSheet.show(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.addCategory),
      ),
      body: switch (categories) {
        AsyncValue(:final value?) when value.isEmpty => Center(child: Text(l10n.emptyCategories)),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminCategoriesProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final parent in value.where((c) => c.isTopLevel)) ...[
                _CategoryTile(category: parent, locale: locale),
                for (final child in value.where((c) => c.parentId == parent.id))
                  _CategoryTile(category: child, locale: locale, indent: true),
              ],
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(adminCategoriesProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.locale, this.indent = false});

  final ProductCategory category;
  final Locale locale;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('admin-category-${category.id}'),
      contentPadding: EdgeInsetsDirectional.only(start: indent ? 48 : 16, end: 16),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(dimension: 40, child: ServerImage(category.imageUrl, icon: Icons.category_outlined)),
      ),
      title: Text(category.localizedName(locale)),
      subtitle: category.isActive ? null : Text(context.l10n.statusHidden),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => CategoryEditSheet.show(context, category),
    );
  }
}

/// Bottom-sheet form for a category.
class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({required this.category, super.key});

  final ProductCategory? category;

  static Future<void> show(BuildContext context, ProductCategory? category) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CategoryEditSheet(category: category),
  );

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _nameGu = TextEditingController(text: widget.category?.nameI18n?['gu']);
  late final _nameHi = TextEditingController(text: widget.category?.nameI18n?['hi']);
  late String? _parentId = widget.category?.parentId;
  late bool _isActive = widget.category?.isActive ?? true;
  late List<AttachedPhoto> _photos = [
    if (widget.category?.imageUrl case final url?) (id: '', thumbUrl: url),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nameGu.dispose();
    _nameHi.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      invalidateCatalog(ref);
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repository = ref.read(adminCatalogRepositoryProvider);
    // An existing image keeps an empty id: leave it unchanged. A new upload sends its id.
    final newImage = _photos.where((p) => p.id.isNotEmpty).firstOrNull?.id;
    final draft = CategoryDraft(
      name: _name.text.trim(),
      nameI18n: {
        if (_nameGu.text.trim().isNotEmpty) 'gu': _nameGu.text.trim(),
        if (_nameHi.text.trim().isNotEmpty) 'hi': _nameHi.text.trim(),
      },
      parentId: _parentId,
      imageMediaId: newImage,
      isActive: _isActive,
    );
    final id = widget.category?.id;
    await _run(() => id == null ? repository.createCategory(draft) : repository.updateCategory(id, draft));
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteCategoryConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) await _run(() => ref.read(adminCatalogRepositoryProvider).deleteCategory(widget.category!.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final parents = (ref.watch(adminCategoriesProvider).value ?? const <ProductCategory>[])
        .where((c) => c.isTopLevel && c.id != widget.category?.id)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(widget.category == null ? l10n.addCategory : l10n.editCategory, style: Theme.of(context).textTheme.titleLarge),
              PhotoPicker(
                photos: _photos,
                max: 1,
                kind: 'CATEGORY_IMAGE',
                onChanged: (photos) => setState(() => _photos = photos),
              ),
              TextFormField(
                key: const Key('categoryNameField'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.nameEnglish, border: const OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
              ),
              TextFormField(
                controller: _nameGu,
                decoration: InputDecoration(labelText: l10n.nameGujarati, border: const OutlineInputBorder()),
              ),
              TextFormField(
                controller: _nameHi,
                decoration: InputDecoration(labelText: l10n.nameHindi, border: const OutlineInputBorder()),
              ),
              DropdownButtonFormField<String?>(
                initialValue: parents.any((p) => p.id == _parentId) ? _parentId : null,
                decoration: InputDecoration(labelText: l10n.parentCategory, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.topLevel)),
                  for (final p in parents) DropdownMenuItem(value: p.id, child: Text(p.localizedName(locale))),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.visibleToCustomers),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              Row(
                spacing: 12,
                children: [
                  if (widget.category != null)
                    OutlinedButton(onPressed: _busy ? null : _delete, child: Text(l10n.delete)),
                  Expanded(
                    child: FilledButton(
                      key: const Key('saveCategoryButton'),
                      onPressed: _busy ? null : _save,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
