import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/server_image.dart';
import 'admin_catalog_providers.dart';

/// Picks a photo and returns its local file path (null when cancelled). Overridden in tests.
typedef PhotoSource = Future<String?> Function({required bool camera});

final photoSourceProvider = Provider<PhotoSource>((ref) {
  final picker = ImagePicker();
  return ({required camera}) async {
    // Downscale on the phone first: faster upload on slow networks; the server re-encodes anyway.
    final file = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return file?.path;
  };
});

/// An attached image: media id + thumbnail path.
typedef AttachedPhoto = ({String id, String thumbUrl});

/// Row of attached photos with remove buttons and an "add photo" tile that uploads immediately.
class PhotoPicker extends ConsumerStatefulWidget {
  const PhotoPicker({
    required this.photos,
    required this.onChanged,
    this.max = 8,
    this.kind = 'PRODUCT_IMAGE',
    super.key,
  });

  final List<AttachedPhoto> photos;
  final ValueChanged<List<AttachedPhoto>> onChanged;
  final int max;
  final String kind;

  @override
  ConsumerState<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends ConsumerState<PhotoPicker> {
  bool _uploading = false;

  Future<void> _add() async {
    final l10n = context.l10n;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.pickFromGallery),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final path = await ref.read(photoSourceProvider)(camera: camera);
    if (path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await ref.read(adminCatalogRepositoryProvider).uploadImage(path, kind: widget.kind);
      widget.onChanged([...widget.photos, (id: uploaded.id, thumbUrl: uploaded.thumbUrl)]);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final photo in widget.photos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(dimension: 88, child: ServerImage(photo.thumbUrl)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: l10n.remove,
                      icon: const Icon(Icons.close),
                      onPressed: () => widget.onChanged([...widget.photos]..remove(photo)),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.photos.length < widget.max)
            SizedBox.square(
              dimension: 88,
              child: OutlinedButton(
                key: const Key('addPhotoButton'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _uploading ? null : _add,
                child: _uploading
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                          const SizedBox(height: 4),
                          Text(l10n.addPhoto, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
