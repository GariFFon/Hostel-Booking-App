import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'pressable.dart';

/// A bordered row: icon, small label, bold value, optional trailing control. Tappable when [onTap] is set.
class TileRow extends StatelessWidget {
  const TileRow({super.key, required this.icon, required this.label, required this.value, this.onTap, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(color: c.card, borderRadius: Radii.baseR, border: Border.all(color: c.input)),
      child: Row(
        children: [
          Icon(icon, size: 22, color: c.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: context.text.bodySmall),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, semanticLabel: '$label: $value', child: row);
  }
}

/// − 2 + control. Buttons are 44 dp hit areas, the limits disable the buttons instead of failing silently,
/// and the spoken labels say what changes ("Fewer guests").
class CountStepper extends StatelessWidget {
  const CountStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged, required this.noun});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Plural noun for the spoken labels: "guests", "beds".
  final String noun;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget button(IconData icon, String name, bool enabled, VoidCallback onTap) => Pressable(
          onTap: enabled ? onTap : null,
          semanticLabel: name,
          minSize: const Size(kMinTap, kMinTap),
          scale: 0.9,
          haptic: true,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: enabled ? c.input : c.border)),
            child: Icon(icon, size: 18, color: enabled ? c.foreground : c.mutedForeground.withValues(alpha: 0.5)),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, 'Fewer $noun', value > min, () => onChanged(value - 1)),
        Semantics(
          liveRegion: true,
          label: '$value $noun',
          excludeSemantics: true,
          child: SizedBox(width: 28, child: Center(child: Text('$value', style: context.text.titleSmall))),
        ),
        button(Icons.add_rounded, 'More $noun', value < max, () => onChanged(value + 1)),
      ],
    );
  }
}
