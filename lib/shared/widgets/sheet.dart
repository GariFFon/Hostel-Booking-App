import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import 'pressable.dart';

/// Modal bottom sheet with the house motion: 300 ms `ease-drawer` in, 140 ms out, drag to dismiss (the framework gives
/// momentum/velocity dismissal and rubber-banding), instant under reduced motion.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    isDismissible: dismissible,
    enableDrag: dismissible,
    sheetAnimationStyle: Motion.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Motion.sheet, reverseDuration: Motion.exit, curve: Motion.easeDrawer, reverseCurve: Curves.easeOut),
    builder: builder,
  );
}

/// Standard sheet layout: grab handle, title with a close button, scrollable body, optional pinned footer.
/// Keyboard-aware (the body lifts above the keyboard) and safe-area-aware.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child, this.footer, this.showClose = true, this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 20)});

  final String title;
  final Widget child;
  final Widget? footer;
  final bool showClose;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return AnimatedPadding(
      duration: Motion.of(context, const Duration(milliseconds: 120)),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.mutedForeground.withValues(alpha: 0.3), borderRadius: Radii.pillR)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text(title, style: context.text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (showClose)
                  Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    semanticLabel: 'Close',
                    minSize: const Size(kMinTap, kMinTap),
                    scale: 0.9,
                    child: Icon(Icons.close_rounded, color: c.mutedForeground),
                  ),
              ],
            ),
          ),
          Flexible(child: SingleChildScrollView(padding: padding, child: child)),
          if (footer != null)
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + (bottomInset > 0 ? 0 : safeBottom)),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: footer,
            ),
        ],
      ),
    );
  }
}
