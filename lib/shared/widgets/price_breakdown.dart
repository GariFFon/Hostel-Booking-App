import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'pressable.dart';

class PriceLine {
  const PriceLine(this.label, this.paise, {this.detail, this.discount = false});
  final String label;
  final int paise;
  final String? detail;
  final bool discount;
}

/// Itemised price: room charges, discount, GST, total. Amounts use tabular figures so columns line up,
/// and are never truncated (the label gives way first).
class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({super.key, required this.lines, required this.totalPaise, this.totalLabel = 'Total', this.note});

  final List<PriceLine> lines;
  final int totalPaise;
  final String totalLabel;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.label, style: t.bodyMedium?.copyWith(color: l.discount ? c.success : null)),
                      if (l.detail != null) Text(l.detail!, style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l.discount ? moneyOff(l.paise) : money(l.paise),
                  style: t.bodyMedium?.copyWith(color: l.discount ? c.success : null, fontWeight: l.discount ? FontWeight.w600 : null).tabular,
                ),
              ],
            ),
          ),
        Divider(color: c.border, height: 12),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(totalLabel, style: t.titleMedium)),
            const SizedBox(width: 12),
            Text(totalPaise == 0 ? 'Free' : money(totalPaise), style: t.titleLarge?.tabular),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(note!, style: t.bodySmall),
            ),
          ),
      ],
    );
  }
}

/// Card surface with a hairline border (the house container). Tappable cards should wrap this in a Pressable.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.foreground.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction,
              semanticLabel: '$action, $title',
              minSize: const Size(kMinTap, kMinTap),
              scale: 0.96,
              child: Text(action!, style: context.text.labelMedium?.copyWith(color: context.colors.primary)),
            ),
        ],
      ),
    );
  }
}
