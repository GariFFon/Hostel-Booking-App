import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'pressable.dart';

/// A grouped card of settings rows separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});
  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!, style: context.text.labelMedium?.copyWith(color: c.mutedForeground)),
          ),
        Container(
          decoration: BoxDecoration(color: c.card, borderRadius: Radii.cardR, border: Border.all(color: c.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 52, color: c.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row: icon, title, optional subtitle, optional trailing widget (a chevron by default when tappable).
/// 56 dp minimum so it is an easy target; text is limited to two lines so a long value never breaks the row.
class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.destructive = false, this.badge = 0});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Unread-style count shown before the chevron.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final fg = destructive ? c.destructive : c.foreground;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: destructive ? c.destructive : c.mutedForeground),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.bodyLarge?.copyWith(color: fg), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (badge > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: c.primary, borderRadius: Radii.pillR),
              child: Text(badge > 99 ? '99+' : '$badge', style: t.labelMedium?.copyWith(color: c.onPrimary, fontSize: 12)),
            ),
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(left: 8), child: trailing)
          else if (onTap != null)
            Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right_rounded, color: c.mutedForeground)),
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: [title, ?subtitle, if (badge > 0) '$badge unread'].join(', '),
      child: row,
    );
  }
}
