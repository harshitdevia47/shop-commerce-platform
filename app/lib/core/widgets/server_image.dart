import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../network/api_client.dart';
import '../providers.dart';

/// Cached image from a server path (`/media/...`). Shows a neutral box while loading or when missing.
class ServerImage extends ConsumerWidget {
  const ServerImage(this.path, {this.fit = BoxFit.cover, this.icon = Icons.image_outlined, super.key});

  final String? path;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: scheme.outline)),
    );
    final path = this.path;
    if (path == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: resolveServerUrl(ref.watch(envConfigProvider).apiBaseUrl, path),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
