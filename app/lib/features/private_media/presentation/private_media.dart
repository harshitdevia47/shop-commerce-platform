import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../admin_catalog/presentation/photo_picker.dart';
import '../../orders/domain/order_models.dart';
import '../data/private_media_repository.dart';

final privateMediaRepositoryProvider = Provider<PrivateMediaRepository>((ref) => HttpPrivateMediaRepository(ref.watch(dioProvider)));

/// Image bytes of a private photo (`thumb` or full size), cached while shown.
final privatePhotoProvider = FutureProvider.autoDispose.family<Uint8List, (String, bool)>(
  (ref, key) => ref.watch(privateMediaRepositoryProvider).bytes(key.$1, thumb: key.$2),
);

/// Thumbnail of a private photo; tap opens it full size.
class PrivatePhoto extends ConsumerWidget {
  const PrivatePhoto({required this.id, this.size = 72, super.key});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(privatePhotoProvider((id, true)));
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('private-photo-$id'),
      onTap: () => showDialog<void>(context: context, builder: (_) => _FullPhoto(id: id)),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: size,
          child: switch (bytes) {
            AsyncValue(:final value?) => Image.memory(
              value,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
            AsyncValue(hasError: true) => ColoredBox(color: scheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined)),
            _ => ColoredBox(color: scheme.surfaceContainerHighest),
          },
        ),
      ),
    );
  }
}

class _FullPhoto extends ConsumerWidget {
  const _FullPhoto({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(privatePhotoProvider((id, false)));
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: switch (bytes) {
              AsyncValue(:final value?) => InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(value))),
              AsyncValue(:final error?) => Center(child: Text(errorMessage(context.l10n, error), style: const TextStyle(color: Colors.white))),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          SafeArea(
            child: IconButton(
              color: Colors.white,
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// An uploaded photo with the local file used for its preview.
typedef PickedAttachment = ({Attachment attachment, String localPath});

/// Photos the customer adds (prescription, list, return photos): uploads right away, shows previews.
class AttachmentField extends ConsumerStatefulWidget {
  const AttachmentField({
    required this.kind,
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 3,
    super.key,
  });

  final AttachmentKind kind;
  final String label;
  final List<PickedAttachment> value;
  final ValueChanged<List<PickedAttachment>> onChanged;
  final int max;

  @override
  ConsumerState<AttachmentField> createState() => _AttachmentFieldState();
}

class _AttachmentFieldState extends ConsumerState<AttachmentField> {
  bool _uploading = false;

  Future<void> _add() async {
    final l10n = context.l10n;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l10n.takePhoto), onTap: () => Navigator.pop(context, true)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l10n.pickFromGallery), onTap: () => Navigator.pop(context, false)),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final path = await ref.read(photoSourceProvider)(camera: camera);
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final attachment = await ref.read(privateMediaRepositoryProvider).upload(path, widget.kind);
      widget.onChanged([...widget.value, (attachment: attachment, localPath: path)]);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final picked in widget.value)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(picked.localPath),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.square(dimension: 80, child: Icon(Icons.image_outlined)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => widget.onChanged([...widget.value]..remove(picked)),
                      child: CircleAvatar(radius: 12, backgroundColor: scheme.surface, child: const Icon(Icons.close, size: 16)),
                    ),
                  ),
                ],
              ),
            if (widget.value.length < widget.max)
              InkWell(
                key: ValueKey('add-${widget.kind.wire}'),
                onTap: _uploading ? null : _add,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(8)),
                  child: _uploading
                      ? const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
