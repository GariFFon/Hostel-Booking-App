import 'package:flutter/material.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/pressable.dart';
import '../domain/review_models.dart';

/// Five stars for a 1-5 score. Spoken as "4 out of 5", never as five separate icons.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= rating ? c.star : c.input),
        ],
      ),
    );
  }
}

/// Text clamped to [maxLines] with a "Read more" toggle that only appears when the text really is longer.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.maxLines = 4, this.style});
  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? context.text.bodyMedium;
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.text, style: style, maxLines: _open ? null : widget.maxLines, overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis),
            if (overflows)
              Pressable(
                onTap: () => setState(() => _open = !_open),
                semanticLabel: _open ? 'Show less' : 'Read more',
                scale: 0.98,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: kMinTap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_open ? 'Show less' : 'Read more', style: context.text.labelMedium?.copyWith(color: c.primary)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One guest review: score, stay, text (rendered as plain text, never HTML) and the host's reply.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.showHostel = false, this.trailing});
  final Review review;
  final bool showHostel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final r = review;
    final name = r.reviewer.name.isEmpty ? 'Guest' : r.reviewer.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHostel && r.hostel != null) Text(r.hostel!.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: showHostel ? t.bodySmall : t.titleSmall),
                  Text([if (r.stay.month.isNotEmpty) r.stay.month, plural(r.stay.nights, 'night')].join(' · '), style: t.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            StarRow(rating: r.overall),
            const SizedBox(width: 8),
            Text(relativeTime(r.createdAt), style: t.bodySmall),
          ],
        ),
        if (r.title != null && r.title!.isNotEmpty) ...[const SizedBox(height: 8), Text(r.title!, style: t.titleSmall)],
        if (r.comment != null && r.comment!.isNotEmpty) ...[const SizedBox(height: 4), ExpandableText(r.comment!)],
        if (r.isHidden) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.tint(c.warning), borderRadius: Radii.baseR),
            child: Text(
              'Hidden by moderators${r.moderationReason == null ? '' : ': ${r.moderationReason}'}',
              style: t.bodySmall?.copyWith(color: c.warning),
            ),
          ),
        ],
        if (r.ownerReply != null && r.ownerReply!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reply from the host', style: t.labelMedium),
                const SizedBox(height: 4),
                ExpandableText(r.ownerReply!, maxLines: 3),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Average, distribution bars and category averages.
class ReviewSummaryView extends StatelessWidget {
  const ReviewSummaryView({super.key, required this.summary});
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final s = summary;
    final cats = <(String, double?)>[
      ('Cleanliness', s.categories.cleanliness),
      ('Location', s.categories.location),
      ('Staff', s.categories.staff),
      ('Value for money', s.categories.valueForMoney),
    ].where((e) => e.$2 != null).toList();
    final maxCount = [for (var i = 1; i <= 5; i++) s.starCount(i)].fold<int>(1, (a, b) => b > a ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reviewCount == 0 ? 'New' : s.avgRating.toStringAsFixed(1), style: t.displaySmall?.tabular),
                Text(plural(s.reviewCount, 'review'), style: t.bodySmall),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 14, child: Text('$star', style: t.bodySmall?.tabular)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: Radii.pillR,
                              child: LinearProgressIndicator(
                                value: s.starCount(star) / maxCount,
                                minHeight: 6,
                                backgroundColor: c.muted,
                                color: c.star,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            child: Text('${s.starCount(star)}', textAlign: TextAlign.end, style: t.bodySmall?.tabular),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              for (final (label, v) in cats)
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.bodySmall),
                      Text(v!.toStringAsFixed(1), style: t.titleSmall?.tabular),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
