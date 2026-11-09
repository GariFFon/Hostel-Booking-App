import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/amenity_icon.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/form_tiles.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../bookings/application/booking_providers.dart';
import '../../bookings/application/stay_selection.dart';
import '../../bookings/presentation/checkout_args.dart';
import '../../reviews/presentation/hostel_reviews_section.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../../wishlist/presentation/wishlist_heart.dart';
import '../application/hostel_providers.dart';
import '../domain/enums.dart';
import '../domain/hostel_models.dart';
import 'gallery.dart';
import 'location_card.dart';
import 'rooms_section.dart';
import 'stay_dates.dart';

class HostelScreen extends ConsumerWidget {
  const HostelScreen({super.key, required this.slug, this.checkIn, this.checkOut, this.guests = 1});

  final String slug;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(hostelDetailProvider(slug));
    return detail.when(
      loading: () => const _HostelSkeleton(),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: e is ApiException && e.isNotFound
            ? EmptyState(icon: Icons.home_work_outlined, title: "This stay isn't available", message: 'It may have been taken down. Browse other places instead.', actionLabel: 'Back to search', onAction: () => context.go(Routes.explore))
            : ErrorState(error: e, onRetry: () => ref.invalidate(hostelDetailProvider(slug))),
      ),
      data: (h) => _HostelBody(hostel: h, stayKey: (slug, checkIn, checkOut, guests)),
    );
  }
}

class _HostelBody extends ConsumerWidget {
  const _HostelBody({required this.hostel, required this.stayKey});
  final HostelDetail hostel;
  final StayKey stayKey;

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final sel = ref.read(staySelectionProvider(stayKey));
    final r = await pickStayDates(context, checkIn: sel.checkIn, checkOut: sel.checkOut);
    if (r != null) ref.read(staySelectionProvider(stayKey).notifier).setDates(r.checkIn, r.checkOut);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final h = hostel;
    final sel = ref.watch(staySelectionProvider(stayKey));
    final notifier = ref.read(staySelectionProvider(stayKey).notifier);
    final topInset = MediaQuery.paddingOf(context).top;

    Widget section(String title, Widget child, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text(title, style: t.headlineSmall)), ?trailing]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        );

    final amenities = h.amenities;
    return Scaffold(
      bottomNavigationBar: _ReserveBar(hostel: h, stayKey: stayKey, onPickDates: () => _pickDates(context, ref)),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: HostelGallery(photos: h.gallery, name: h.name)),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name, style: t.headlineMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RatingBadge(rating: h.avgRating, reviews: h.reviewCount, size: 15),
                            InfoPill(h.propertyType.label),
                            if (h.genderPolicy != GenderPolicy.mixed) InfoPill(h.genderPolicy.label, icon: Icons.group_outlined),
                            h.bookingMode.isInstant ? const InfoPill('Instant book', icon: Icons.bolt_rounded) : const InfoPill('Request to book', icon: Icons.mark_email_unread_outlined),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.place_outlined, size: 18, color: c.mutedForeground),
                            const SizedBox(width: 6),
                            Expanded(child: Text([if (h.address.locality != null && h.address.locality!.isNotEmpty) h.address.locality!, h.address.city, h.address.state].where((s) => s.isNotEmpty).join(', '), style: t.bodyMedium?.copyWith(color: c.mutedForeground))),
                          ],
                        ),
                        if (h.host.name != null && h.host.name!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [Icon(Icons.person_outline_rounded, size: 18, color: c.mutedForeground), const SizedBox(width: 6), Expanded(child: Text('Hosted by ${h.host.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: c.mutedForeground)))]),
                        ],
                      ],
                    ),
                  ),
                  section(
                    'Your stay',
                    Column(
                      children: [
                        TileRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Dates',
                          value: sel.hasDates ? '${fmtRange(sel.checkIn!, sel.checkOut!)} · ${plural(sel.nights, 'night')}' : 'Add dates to see prices',
                          onTap: () => _pickDates(context, ref),
                          trailing: sel.hasDates
                              ? Pressable(onTap: notifier.clearDates, semanticLabel: 'Clear dates', minSize: const Size(kMinTap, kMinTap), child: Icon(Icons.close_rounded, size: 20, color: c.mutedForeground))
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TileRow(icon: Icons.group_outlined, label: 'Guests', value: plural(sel.guests, 'guest'), trailing: CountStepper(value: sel.guests, min: 1, max: 30, onChanged: notifier.setGuests, noun: 'guests')),
                      ],
                    ),
                  ),
                  section('Rooms', RoomsSection(hostel: h, stayKey: stayKey, onPickDates: () => _pickDates(context, ref))),
                  if (h.description.trim().isNotEmpty) section('About this place', ExpandableText(h.description.trim(), maxLines: 5, style: t.bodyLarge)),
                  if (amenities.isNotEmpty)
                    section(
                      'What this place offers',
                      Column(
                        children: [
                          Wrap(
                            runSpacing: 12,
                            children: [
                              for (final a in amenities.take(8))
                                SizedBox(
                                  width: (MediaQuery.sizeOf(context).width - 32) / 2,
                                  child: Row(children: [Icon(amenityIcon(a.code), size: 22, color: c.foreground), const SizedBox(width: 10), Expanded(child: Text(a.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium))]),
                                ),
                            ],
                          ),
                          if (amenities.length > 8) ...[
                            const SizedBox(height: 12),
                            AppButton(label: 'Show all ${amenities.length} amenities', onPressed: () => _showAmenities(context, amenities), variant: AppButtonVariant.secondary),
                          ],
                        ],
                      ),
                    ),
                  section(
                    h.reviewCount > 0 ? 'Reviews' : 'Reviews',
                    HostelReviewsSection(slug: h.slug, reviewCount: h.reviewCount),
                  ),
                  section('Where you will be', LocationCard(name: h.name, address: h.address, location: h.location)),
                  section(
                    'Good to know',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Fact(icon: Icons.login_rounded, label: 'Check-in', value: 'From ${fmtClock(h.checkInTime)}'),
                        _Fact(icon: Icons.logout_rounded, label: 'Check-out', value: 'By ${fmtClock(h.checkOutTime)}'),
                        _Fact(icon: Icons.event_available_outlined, label: 'Cancellation: ${h.cancellation.policy.label}', value: h.cancellation.summary),
                        if (h.houseRules != null && h.houseRules!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('House rules', style: t.titleSmall),
                          const SizedBox(height: 4),
                          ExpandableText(h.houseRules!.trim(), maxLines: 4),
                        ],
                        if (h.tax.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(h.tax.note, style: t.bodySmall)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ],
          ),
          Positioned(
            top: topInset + 6,
            left: 8,
            right: 8,
            child: Row(
              children: [
                Pressable(
                  onTap: () => context.canPop() ? context.pop() : context.go(Routes.explore),
                  semanticLabel: 'Back',
                  minSize: const Size(kMinTap, kMinTap),
                  scale: 0.9,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.card.withValues(alpha: 0.94), shape: BoxShape.circle, border: Border.all(color: c.border)),
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: c.foreground),
                  ),
                ),
                const Spacer(),
                WishlistHeart(hostelId: h.id, hostelName: h.name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAmenities(BuildContext context, List<Amenity> all) {
    final byCategory = <String, List<Amenity>>{};
    for (final a in all) {
      byCategory.putIfAbsent(a.category.isEmpty ? 'OTHER' : a.category, () => []).add(a);
    }
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetFrame(
        title: 'All amenities',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in byCategory.entries) ...[
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(humanize(e.key), style: ctx.text.titleSmall)),
              for (final a in e.value) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(amenityIcon(a.code), size: 22), const SizedBox(width: 12), Expanded(child: Text(a.label, style: ctx.text.bodyLarge))])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: c.mutedForeground),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: context.text.titleSmall), if (value.isNotEmpty) Text(value, style: context.text.bodyMedium?.copyWith(color: c.mutedForeground))])),
        ],
      ),
    );
  }
}

/// Sticky bottom bar: the live total for the selection (a real quote incl. GST) and the one action that makes sense next.
class _ReserveBar extends ConsumerWidget {
  const _ReserveBar({required this.hostel, required this.stayKey, required this.onPickDates});
  final HostelDetail hostel;
  final StayKey stayKey;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final sel = ref.watch(staySelectionProvider(stayKey));
    final instant = hostel.bookingMode.isInstant;
    final cta = instant ? 'Reserve' : 'Request to book';

    String headline;
    String? sub;
    Widget button;
    final capacity = sel.capacity(hostel);

    if (!sel.hasDates) {
      headline = hostel.fromPricePaise == null ? 'No rooms listed' : 'From ${money(hostel.fromPricePaise)}';
      sub = 'per night · pick dates for the exact price';
      button = AppButton(label: 'Select dates', onPressed: onPickDates, expand: false);
    } else if (sel.isEmpty) {
      headline = '${fmtRange(sel.checkIn!, sel.checkOut!)} · ${plural(sel.nights, 'night')}';
      sub = 'Choose your beds or rooms above';
      button = AppButton(label: cta, onPressed: null, expand: false);
    } else if (capacity < sel.guests) {
      headline = 'Room for $capacity, not ${sel.guests}';
      sub = 'Add more beds or rooms for your group';
      button = AppButton(label: cta, onPressed: null, expand: false);
    } else {
      final quote = ref.watch(quoteProvider(QuoteArgs(hostelId: hostel.id, checkIn: sel.checkIn!, checkOut: sel.checkOut!, guests: sel.guests, items: sel.items)));
      headline = quote.when(data: (q) => q.totalPaise == 0 ? 'Free' : money(q.totalPaise), loading: () => 'Pricing…', error: (_, _) => 'Price unavailable');
      sub = quote.when(data: (q) => '${plural(q.nights, 'night')} · incl. taxes', loading: () => 'Checking availability', error: (e, _) => errorText(e));
      button = AppButton(
        label: cta,
        loading: quote.isLoading,
        onPressed: quote.hasValue
            ? () {
                final args = CheckoutArgs(hostel: hostel, checkIn: sel.checkIn!, checkOut: sel.checkOut!, guests: sel.guests, items: sel.items);
                ref.read(pendingCheckoutProvider.notifier).set(args);
                context.push(Routes.checkout, extra: args);
              }
            : (quote.hasError ? () => ref.invalidate(quoteProvider) : null),
        expand: false,
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleLarge?.tabular),
                if (sub != null) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          button,
        ],
      ),
    );
  }
}

class _HostelSkeleton extends StatelessWidget {
  const _HostelSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Skeleton(
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            AspectRatio(aspectRatio: 1.2, child: SkeletonBox(height: double.infinity, radius: 0)),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [SkeletonBox(width: 260, height: 28), SizedBox(height: 12), SkeletonBox(width: 180, height: 16), SizedBox(height: 28), SkeletonBox(height: 60, radius: 12), SizedBox(height: 12), SkeletonBox(height: 60, radius: 12), SizedBox(height: 28), SkeletonBox(height: 140, radius: 16)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
