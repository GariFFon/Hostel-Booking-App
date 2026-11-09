import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Network image that never shows a broken-image glyph or a layout jump: a quiet placeholder while loading, a neutral
/// "no photo" tile on failure or when the url is missing. Always `cover`; the parent decides the size.
class AppImage extends StatelessWidget {
  const AppImage({super.key, required this.url, this.semanticLabel, this.fit = BoxFit.cover, this.cacheWidth});

  final String? url;
  final String? semanticLabel;
  final BoxFit fit;

  /// Decode at roughly this many logical pixels wide (multiplied by the device ratio) to keep memory low in long lists.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fallback() => Container(
          color: c.muted,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: c.mutedForeground.withValues(alpha: 0.7), size: 28),
        );
    if (url == null || url!.isEmpty) return ExcludeSemantics(child: fallback());

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: cacheWidth == null ? null : (cacheWidth! * dpr).round(),
      fadeInDuration: Motion.of(context, const Duration(milliseconds: 160)),
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => Container(color: c.muted),
      errorWidget: (_, _, _) => fallback(),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: image);
    return Semantics(image: true, label: semanticLabel, child: image);
  }
}
