import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import 'app_button.dart';

/// Designed empty state: says what is empty and what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: c.accentForeground),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.mutedForeground)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                AppButton(label: actionLabel!, onPressed: onAction, expand: false, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Says what happened (in words, not an exception) and offers a retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;

  /// Inline variant for sections inside a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final offline = error is ApiException && (error as ApiException).isNetwork;
    final title = offline ? "You're offline" : "Couldn't load this";
    final body = errorText(error);
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.card, borderRadius: Radii.cardR, border: Border.all(color: c.border)),
        child: Row(
          children: [
            Icon(icon, color: c.mutedForeground),
            const SizedBox(width: 12),
            Expanded(child: Text(body, style: context.text.bodyMedium)),
            if (onRetry != null) AppButton(label: 'Retry', onPressed: onRetry, variant: AppButtonVariant.ghost, expand: false, compact: true),
          ],
        ),
      );
    }
    return EmptyState(icon: icon, title: title, message: body, actionLabel: onRetry == null ? null : 'Try again', onAction: onRetry);
  }
}

/// One pulse for a whole skeleton subtree (a single controller, not one per box). Static when reduced motion is on.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    return super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      excludeSemantics: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.55).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    );
  }
}

/// A placeholder block at the final size of what will replace it.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.colors.muted, borderRadius: BorderRadius.circular(radius)),
      );
}

/// A vertical list of card-shaped skeletons.
class CardSkeletonList extends StatelessWidget {
  const CardSkeletonList({super.key, this.count = 3, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)});
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: SkeletonBox(height: double.infinity, radius: 16)),
            SizedBox(height: 12),
            SkeletonBox(width: 220, height: 18),
            SizedBox(height: 8),
            SkeletonBox(width: 140, height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 90, height: 16),
          ],
        ),
      ),
    );
  }
}

/// Thin row skeletons (notifications, trips).
class RowSkeletonList extends StatelessWidget {
  const RowSkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => const Row(
          children: [
            SkeletonBox(width: 72, height: 72, radius: 14),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [SkeletonBox(height: 16), SizedBox(height: 8), SkeletonBox(width: 140, height: 13), SizedBox(height: 8), SkeletonBox(width: 80, height: 13)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
