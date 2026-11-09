import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Equal-width segmented control for filters and view switches (not tabs: peers, no sliding content).
/// The pill moves with a 200 ms ease-out; the selection ticks a light haptic.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({super.key, required this.options, required this.value, required this.onChanged, this.semanticLabel});

  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedIndex = options.indexWhere((o) => o.value == value).clamp(0, options.length - 1);
    final align = options.length <= 1 ? 0.0 : -1 + 2 * selectedIndex / (options.length - 1);

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(align, 0),
              duration: Motion.of(context, const Duration(milliseconds: 200)),
              curve: Motion.easeOut,
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(Radii.control),
                    border: Border.all(color: c.border),
                    boxShadow: [BoxShadow(color: c.foreground.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final o in options)
                  Expanded(
                    child: Semantics(
                      inMutuallyExclusiveGroup: true,
                      selected: o.value == value,
                      button: true,
                      label: o.label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (o.value != value) {
                            HapticFeedback.selectionClick();
                            onChanged(o.value);
                          }
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              o.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelMedium?.copyWith(
                                color: o.value == value ? c.foreground : c.mutedForeground,
                                fontWeight: o.value == value ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
