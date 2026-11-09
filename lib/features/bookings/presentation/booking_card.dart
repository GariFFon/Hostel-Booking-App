import 'package:flutter/material.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/countdown.dart';
import '../../../shared/widgets/pressable.dart';
import '../domain/booking_models.dart';

/// One booking in a list (guest trips, host bookings). Every text has a line limit so a long property or guest name
/// can never push the price or status off the card.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap, this.showGuest = false});

  final BookingSummary booking;
  final VoidCallback onTap;

  /// Host lists show who booked instead of nothing.
  final bool showGuest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final b = booking;
    final guest = (b.guestName ?? '').trim();

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel:
          '${b.hostel.name}, ${fmtRange(b.checkIn, b.checkOut)}, ${plural(b.nights, 'night')}. ${b.status.label}.${showGuest && guest.isNotEmpty ? ' Guest $guest.' : ''}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: c.foreground.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: SizedBox(
                width: 76,
                height: 76,
                child: AppImage(url: b.hostel.coverUrl, cacheWidth: 76, semanticLabel: b.hostel.name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.hostel.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtRange(b.checkIn, b.checkOut)} · ${plural(b.nights, 'night')}',
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showGuest && guest.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: c.mutedForeground),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$guest · ${plural(b.guestsCount, 'guest')}',
                              style: t.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(child: BookingStatusChip(b.status)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.totalPaise == 0 ? 'Free' : money(b.totalPaise),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall?.tabular,
                        ),
                      ),
                    ],
                  ),
                  if (!showGuest && b.holdExpiresAt != null && (b.status == BookingStatus.pendingPayment || b.status == BookingStatus.hold))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Countdown(
                        until: b.holdExpiresAt!,
                        builder: (_, remaining) => Text(
                          remaining == Duration.zero ? 'Hold expired' : 'Pay within ${fmtCountdown(remaining)}',
                          style: t.labelMedium?.copyWith(color: remaining == Duration.zero ? c.destructive : c.warning, fontSize: 12).tabular,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
