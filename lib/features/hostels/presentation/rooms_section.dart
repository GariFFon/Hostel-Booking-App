import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/form_tiles.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/states.dart';
import '../../bookings/application/stay_selection.dart';
import '../application/hostel_providers.dart';
import '../domain/enums.dart';
import '../domain/hostel_models.dart';
import '../../reviews/presentation/review_widgets.dart';

/// Room types with live availability for the chosen dates, and a stepper per type.
/// Without dates there is nothing to be available *for*, so the section asks for dates first.
class RoomsSection extends ConsumerWidget {
  const RoomsSection({super.key, required this.hostel, required this.stayKey, required this.onPickDates});

  final HostelDetail hostel;
  final StayKey stayKey;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(staySelectionProvider(stayKey));
    final availability = sel.hasDates ? ref.watch(availabilityProvider(AvailabilityArgs(hostel.slug, sel.checkIn!, sel.checkOut!, sel.guests))) : null;

    if (hostel.roomTypes.isEmpty) {
      return const SurfaceCard(child: Text('This property has not listed any rooms yet.'));
    }
    return Column(
      children: [
        if (availability != null && availability.hasError)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: ErrorState(error: availability.error!, compact: true, onRetry: () => ref.invalidate(availabilityProvider))),
        for (final room in hostel.roomTypes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoomCard(
              room: room,
              hostel: hostel,
              selection: sel,
              availability: availability?.value?.forRoom(room.id),
              loading: availability?.isLoading ?? false,
              onPickDates: onPickDates,
              onUnits: (n) => ref.read(staySelectionProvider(stayKey).notifier).setUnits(room.id, n),
            ),
          ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.hostel, required this.selection, required this.availability, required this.loading, required this.onPickDates, required this.onUnits});

  final RoomType room;
  final HostelDetail hostel;
  final StaySelection selection;
  final RoomAvailability? availability;
  final bool loading;
  final VoidCallback onPickDates;
  final ValueChanged<int> onUnits;

  String? _ineligibleMessage(RoomAvailability a) => switch (a.reason) {
        'SOLD_OUT' => 'Sold out for these dates',
        'MIN_STAY' => 'Minimum stay is ${plural(room.minStayNights, 'night')}',
        'MAX_STAY' => 'Maximum stay is ${plural(room.maxStayNights, 'night')}',
        _ => 'Not available for these dates',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final units = selection.units[room.id] ?? 0;
    final a = availability;
    final cover = room.media.isEmpty ? null : room.media.first.cardUrl;
    final per = room.priceUnit == PriceUnit.month ? 'month' : 'night';

    Widget action;
    if (!selection.hasDates) {
      action = Row(
        children: [
          Expanded(child: _Price(label: 'From', paise: room.fromPricePaise, per: per)),
          AppButton(label: 'Select dates', onPressed: onPickDates, variant: AppButtonVariant.secondary, expand: false, compact: true),
        ],
      );
    } else if (loading || a == null) {
      action = const Skeleton(child: Row(children: [SkeletonBox(width: 120, height: 20), Spacer(), SkeletonBox(width: 96, height: 32, radius: 16)]));
    } else if (!a.eligible || a.availableUnits <= 0) {
      action = Row(children: [StatusChip(_ineligibleMessage(a)!, tone: Tone.neutral, icon: Icons.event_busy_rounded)]);
    } else {
      final left = a.availableUnits;
      action = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Price(label: null, paise: a.avgNightlyPaise ?? room.fromPricePaise, per: 'night avg'),
                if (a.stayPerUnitPaise != null) Text('${money(a.stayPerUnitPaise)} for ${plural(selection.nights, 'night')}', style: t.bodySmall?.tabular),
                if (left <= 3) Text('Only $left ${unitNoun(room.kind, n: left)} left', style: t.bodySmall?.copyWith(color: c.warning, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CountStepper(value: units, min: 0, max: left.clamp(0, 30), onChanged: onUnits, noun: unitNoun(room.kind, n: 2)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: Radii.cardR,
        border: Border.all(color: units > 0 ? c.primary : c.border, width: units > 0 ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 84, height: 84, child: AppImage(url: cover, cacheWidth: 168))),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InfoPill(room.kind.label, icon: room.kind == RoomKind.dorm ? Icons.bed_outlined : Icons.meeting_room_outlined),
                        if (room.gender != RoomGender.mixed) InfoPill('${room.gender.label} only'),
                        if (room.kind == RoomKind.private || room.maxOccupancyPerUnit > 1) InfoPill('Sleeps ${room.maxOccupancyPerUnit}', icon: Icons.group_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (room.description != null && room.description!.isNotEmpty) ...[const SizedBox(height: 8), ExpandableText(room.description!, maxLines: 3, style: t.bodyMedium?.copyWith(color: c.mutedForeground))],
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),
          action,
          if (units > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('$units ${unitNoun(room.kind, n: units)} selected for your stay', style: t.labelMedium?.copyWith(color: c.accentForeground)),
            ),
          if (selection.hasDates && a != null && a.eligible && room.minStayNights > 1) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Min stay ${plural(room.minStayNights, 'night')}', style: t.bodySmall)),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.label, required this.paise, required this.per});
  final String? label;
  final int paise;
  final String per;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Text.rich(
      TextSpan(
        children: [
          if (label != null) TextSpan(text: '$label ', style: t.bodySmall),
          TextSpan(text: money(paise), style: t.titleMedium?.tabular),
          TextSpan(text: ' / $per', style: t.bodySmall),
        ],
      ),
    );
  }
}
