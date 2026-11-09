import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Press feedback for everything tappable: the content scales to 0.97 the instant the finger lands (not on release)
/// and eases back. Reduced motion drops the scale. One scale on both platforms, no ripple.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
    this.semanticLabel,
    this.minSize,
    this.enabled = true,
    this.mergeSemantics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// A light selection tick on tap. Use for commits (save, toggle), never for navigation taps.
  final bool haptic;
  final String? semanticLabel;

  /// Hit area for small visuals (icons): at least 44x44 without growing the visual.
  final Size? minSize;
  final bool enabled;
  final bool mergeSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    final scale = _down && !Motion.reduced(context) ? widget.scale : 1.0;

    Widget content = AnimatedScale(
      scale: scale,
      duration: _down ? Motion.press : Motion.pressRelease,
      curve: Motion.easeOut,
      child: widget.child,
    );
    final min = widget.minSize;
    if (min != null) {
      content = ConstrainedBox(constraints: BoxConstraints(minWidth: min.width, minHeight: min.height), child: Center(widthFactor: 1, heightFactor: 1, child: content));
    }

    Widget detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active && widget.onTap != null
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      onLongPress: active ? widget.onLongPress : null,
      child: content,
    );

    detector = Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
      onTap: active ? widget.onTap : null,
      child: detector,
    );
    return widget.mergeSemantics ? MergeSemantics(child: detector) : detector;
  }
}

/// A small icon with a 44x44 hit area and a mandatory spoken label.
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.label, required this.onPressed, this.color, this.size = 24, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  /// A subtle circular backdrop (for icons floating over photos).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget visual = Icon(icon, size: size, color: color ?? c.foreground);
    if (filled) {
      visual = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: c.card.withValues(alpha: 0.92), shape: BoxShape.circle, border: Border.all(color: c.border)),
        child: Icon(icon, size: size - 4, color: color ?? c.foreground),
      );
    }
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      minSize: const Size(kMinTap, kMinTap),
      scale: 0.92,
      child: visual,
    );
  }
}
