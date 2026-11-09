import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The app mark: a teal rounded square with a night-shelter glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(Icons.night_shelter_rounded, color: c.onPrimary, size: size * 0.55),
    );
  }
}
