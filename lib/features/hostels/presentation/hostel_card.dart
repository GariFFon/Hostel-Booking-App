import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/pressable.dart';
import '../../wishlist/presentation/wishlist_heart.dart';
import '../domain/enums.dart';
import '../domain/hostel_models.dart';

/// One listing in a list: photo carousel, heart, name + rating, place, price. Every text has a line limit so no
/// realistic name breaks the layout; the full name is always on the detail page.
class HostelCardView extends StatelessWidget {
  const HostelCardView({super.key, required this.hostel, this.checkIn, this.checkOut, this.guests});

  final HostelCard hostel;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? guests;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final h = hostel;
    final price = h.shownPricePaise;
    final kinds = h.roomKinds.isEmpty
        ? null
        : h.roomKinds.map((k) => k == RoomKind.dorm ? 'Dorm beds' : (k == RoomKind.private ? 'Private rooms' : 'Rooms')).toSet().join(' & ');
    final meta = [h.propertyType.label, ?kinds, if (h.genderPolicy != GenderPolicy.mixed) h.genderPolicy.label].join(' · ');
    final distance = h.distanceKm == null ? null : '${h.distanceKm! < 10 ? h.distanceKm!.toStringAsFixed(1) : h.distanceKm!.round()} km away';

    return Pressable(
      scale: 0.985,
      semanticLabel: '${h.name}, ${h.place}. ${price == null ? 'No rooms listed' : 'From ${money(price)} per night'}. ${h.reviewCount > 0 ? 'Rated ${ratingLabel(h.avgRating, h.reviewCount)}' : 'New'}.',
      onTap: () => context.push(Routes.hostel(h.slug, checkIn: checkIn, checkOut: checkOut, guests: guests)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: Radii.cardR,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Photos(urls: h.images),
                  Positioned(top: 2, right: 2, child: WishlistHeart(hostelId: h.id, hostelName: h.name)),
                  if (h.bookingMode.isInstant)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: c.card.withValues(alpha: 0.94), borderRadius: Radii.pillR, border: Border.all(color: c.border)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: c.primary),
                            const SizedBox(width: 2),
                            Text('Instant book', style: t.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium)),
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 2), child: RatingBadge(rating: h.avgRating, reviews: h.reviewCount)),
            ],
          ),
          const SizedBox(height: 2),
          Text([h.place, ?distance].where((s) => s.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          const SizedBox(height: 6),
          if (price == null)
            Text('No rooms listed yet', style: t.bodySmall)
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: money(price), style: t.titleMedium?.tabular),
                  TextSpan(text: h.stayFromPricePaise != null ? ' avg per night' : ' per night', style: t.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Swipeable photo strip with page dots. Only the visible page (plus its neighbour) is decoded.
class _Photos extends StatefulWidget {
  const _Photos({required this.urls});
  final List<String> urls;

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.length <= 1) return AppImage(url: urls.isEmpty ? null : urls.first, cacheWidth: 600);
    final c = context.colors;
    final shown = urls.length.clamp(0, 6);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => AppImage(url: urls[i], cacheWidth: 600),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < shown; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: (_page.clamp(0, shown - 1) == i ? c.card : c.card.withValues(alpha: 0.55))),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
