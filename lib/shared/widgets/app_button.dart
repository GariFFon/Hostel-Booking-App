import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

/// The one button. Scales on press, keeps its width while loading (spinner replaces the icon), never shifts layout.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  /// 48 dp tall instead of 52 (still a full touch target).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (c.primary, c.onPrimary, Colors.transparent),
      AppButtonVariant.secondary => (c.card, c.foreground, c.input),
      AppButtonVariant.ghost => (Colors.transparent, c.primary, Colors.transparent),
      AppButtonVariant.destructive => (c.destructive, Colors.white, Colors.transparent),
    };
    final enabled = onPressed != null && !loading;
    final height = compact ? kMinTap : 52.0;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 20, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge?.copyWith(color: fg),
          ),
        ),
      ],
    );

    return AnimatedOpacity(
      opacity: onPressed == null && !loading ? 0.45 : 1,
      duration: Motion.of(context, Motion.fade),
      child: Pressable(
        onTap: enabled ? onPressed : null,
        semanticLabel: loading ? '$label, loading' : label,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.baseR,
            border: Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}
