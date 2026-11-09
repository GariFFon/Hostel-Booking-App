import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../features/bookings/domain/booking_models.dart';
import '../../features/host/domain/host_models.dart';

enum Tone { success, warning, danger, info, neutral }

/// Tinted status chip: token colour at ~12% as the background, the token itself as the text (AA in both themes).
/// Never colour alone: the label always says what it is.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = switch (tone) {
      Tone.success => c.success,
      Tone.warning => c.warning,
      Tone.danger => c.destructive,
      Tone.info => c.info,
      Tone.neutral => c.mutedForeground,
    };
    final bg = tone == Tone.neutral ? c.muted : c.tint(fg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.pillR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

Tone bookingTone(BookingStatus s) => switch (s) {
      BookingStatus.confirmed || BookingStatus.checkedIn => Tone.success,
      BookingStatus.hold || BookingStatus.pendingPayment || BookingStatus.pendingApproval => Tone.warning,
      BookingStatus.completed => Tone.info,
      BookingStatus.cancelledByGuest || BookingStatus.cancelledByOwner || BookingStatus.rejected || BookingStatus.noShow => Tone.danger,
      BookingStatus.expired || BookingStatus.unknown => Tone.neutral,
    };

class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(status.label, tone: bookingTone(status));
}

Tone listingTone(ListingStatus s) => switch (s) {
      ListingStatus.approved => Tone.success,
      ListingStatus.pendingReview || ListingStatus.draft => Tone.warning,
      ListingStatus.rejected || ListingStatus.suspended => Tone.danger,
      ListingStatus.unknown => Tone.neutral,
    };

/// A neutral label pill (property type, gender policy, ...).
class InfoPill extends StatelessWidget {
  const InfoPill(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.muted, borderRadius: Radii.pillR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c.mutedForeground), const SizedBox(width: 5)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(fontSize: 12))),
        ],
      ),
    );
  }
}

/// ★ 4.8 (123). Reads "New" before the first review, so a zero never looks like a bad score.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, required this.reviews, this.showCount = true, this.size = 14});
  final double rating;
  final int reviews;
  final bool showCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final isNew = reviews <= 0;
    final label = isNew ? 'New' : 'Rated ${ratingLabel(rating, reviews)} out of 5 from ${plural(reviews, 'review')}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isNew) Icon(Icons.star_rounded, size: size + 2, color: c.star),
          if (!isNew) const SizedBox(width: 2),
          Text(ratingLabel(rating, reviews), style: t.labelMedium?.copyWith(fontSize: size - 1, fontWeight: FontWeight.w600).tabular),
          if (!isNew && showCount) Text(' (${count(reviews)})', style: t.bodySmall?.copyWith(fontSize: size - 1).tabular),
        ],
      ),
    );
  }
}
