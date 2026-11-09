import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/tokens.dart';

/// Round avatar: the photo when there is one, otherwise initials (grapheme-safe: emoji-first or one-word names still work).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44});
  final String? name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget letters() => Center(
          child: Text(
            initials(name),
            style: context.text.titleSmall?.copyWith(color: c.accentForeground, fontSize: size * 0.38, height: 1),
          ),
        );
    return Semantics(
      label: name == null || name!.trim().isEmpty ? 'Profile photo' : '$name, profile photo',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: ColoredBox(
            color: c.accent,
            child: url == null || url!.isEmpty
                ? letters()
                : CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                    placeholder: (_, _) => letters(),
                    errorWidget: (_, _, _) => letters(),
                    fadeInDuration: const Duration(milliseconds: 120),
                  ),
          ),
        ),
      ),
    );
  }
}
