import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../bookings/presentation/booking_action_sheets.dart';
import '../../bookings/presentation/booking_card.dart';
import '../../reviews/domain/review_models.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../application/host_providers.dart';
import '../domain/host_models.dart';
import 'host_gate.dart';

/// Bookings for the host: requests first, then upcoming, then past.
class HostBookingsScreen extends ConsumerStatefulWidget {
  const HostBookingsScreen({super.key, this.initial = HostBookingTab.upcoming});
  final HostBookingTab initial;

  @override
  ConsumerState<HostBookingsScreen> createState() => _HostBookingsScreenState();
}

class _HostBookingsScreenState extends ConsumerState<HostBookingsScreen> {
  late HostBookingTab _tab = widget.initial;

  @override
  Widget build(BuildContext context) {
    final provider = hostBookingsProvider(_tab);
    return HostGate(
      title: 'Bookings',
      child: Scaffold(
        appBar: AppBar(title: const Text('Bookings')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AppSegmented<HostBookingTab>(
                semanticLabel: 'Bookings filter',
                options: [for (final t in HostBookingTab.values) (value: t, label: t.label)],
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            Expanded(
              child: PagedScroll(
                key: ValueKey(_tab),
                value: ref.watch(provider),
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                empty: EmptyState(
                  icon: _tab == HostBookingTab.requests ? Icons.inbox_outlined : Icons.luggage_outlined,
                  title: switch (_tab) {
                    HostBookingTab.requests => 'No requests waiting',
                    HostBookingTab.upcoming => 'No upcoming bookings',
                    HostBookingTab.past => 'No past bookings',
                  },
                  message: switch (_tab) {
                    HostBookingTab.requests => 'Request-to-book stays that need your decision show up here.',
                    HostBookingTab.upcoming => 'Confirmed and in-progress stays show up here.',
                    HostBookingTab.past => 'Completed and cancelled bookings show up here.',
                  },
                ),
                itemBuilder: (context, b, _) => BookingCard(booking: b, showGuest: true, onTap: () => context.push(Routes.hostBooking(b.id))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host's properties with their review status. Editing happens on the website.
class HostListingsScreen extends ConsumerWidget {
  const HostListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HostGate(
      title: 'Your listings',
      child: Scaffold(
        appBar: AppBar(title: const Text('Your listings')),
        body: PagedScroll(
          value: ref.watch(hostHostelsProvider),
          onLoadMore: () => ref.read(hostHostelsProvider.notifier).loadMore(),
          onRefresh: () async {
            ref.invalidate(hostHostelsProvider);
            await ref.read(hostHostelsProvider.future);
          },
          empty: const EmptyState(
            icon: Icons.home_work_outlined,
            title: 'No listings yet',
            message: 'Add your first property on the website. Once it is approved it shows up here and in search.',
          ),
          itemBuilder: (context, h, _) => _ListingCard(hostel: h),
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.hostel});
  final OwnerHostel hostel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final h = hostel;
    final live = h.status == ListingStatus.approved;
    final facts = [
      h.propertyType.label,
      if (h.city.isNotEmpty) h.city,
      plural(h.roomTypeCount, 'room type'),
      if (h.minPricePaise != null) 'from ${money(h.minPricePaise)}',
    ].join(' · ');

    return Pressable(
      onTap: live ? () => context.push(Routes.hostel(h.slug)) : null,
      scale: 0.985,
      semanticLabel: '${h.name}, ${h.status.label}. $facts',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.card, borderRadius: Radii.cardR, border: Border.all(color: c.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: SizedBox(width: 76, height: 76, child: AppImage(url: h.coverUrl, cacheWidth: 76, semanticLabel: h.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(facts, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusChip(h.status.label, tone: listingTone(h.status)),
                          const Spacer(),
                          RatingBadge(rating: h.avgRating, reviews: h.reviewCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (h.status == ListingStatus.rejected && (h.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.tint(c.destructive), borderRadius: Radii.baseR),
                child: Text('Needs changes: ${h.rejectionReason}', style: t.bodySmall?.copyWith(color: c.foreground)),
              ),
            ],
            if (h.mediaCount == 0 && h.status == ListingStatus.draft) ...[
              const SizedBox(height: 8),
              Text('Add photos before submitting this listing for review.', style: t.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ReplyFilter { needsReply, replied, all }

/// Guest reviews of the host's properties, with reply and report.
class HostReviewsScreen extends ConsumerStatefulWidget {
  const HostReviewsScreen({super.key});

  @override
  ConsumerState<HostReviewsScreen> createState() => _HostReviewsScreenState();
}

class _HostReviewsScreenState extends ConsumerState<HostReviewsScreen> {
  _ReplyFilter _filter = _ReplyFilter.needsReply;

  bool? get _replied => switch (_filter) {
        _ReplyFilter.needsReply => false,
        _ReplyFilter.replied => true,
        _ReplyFilter.all => null,
      };

  Future<void> _reply(Review r) async {
    final text = await showAppSheet<String>(context, builder: (_) => _ReplySheet(initial: r.ownerReply));
    if (text == null) return;
    try {
      await ref.read(hostRepositoryProvider).reply(r.id, text);
      ref.invalidate(hostReviewsProvider);
      if (mounted) showToast(context, r.ownerReply == null ? 'Reply posted' : 'Reply updated');
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _deleteReply(Review r) async {
    if (!await confirmAction(context, title: 'Delete your reply?', confirmLabel: 'Delete', destructive: true)) return;
    try {
      await ref.read(hostRepositoryProvider).deleteReply(r.id);
      ref.invalidate(hostReviewsProvider);
      if (mounted) showToast(context, 'Reply deleted');
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _report(Review r) async {
    final res = await showReasonSheet(
      context,
      title: 'Report this review',
      message: 'Moderators look at reports that break the review rules. Tell us what is wrong with it.',
      confirmLabel: 'Send report',
      hint: 'What is wrong with this review?',
    );
    if (res == null) return;
    try {
      await ref.read(hostRepositoryProvider).report(r.id, res.reason);
      if (mounted) showToast(context, 'Thanks. Our team will take a look.');
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = hostReviewsProvider(_replied);
    return HostGate(
      title: 'Reviews',
      child: Scaffold(
        appBar: AppBar(title: const Text('Reviews')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AppSegmented<_ReplyFilter>(
                semanticLabel: 'Reviews filter',
                options: const [(value: _ReplyFilter.needsReply, label: 'Needs reply'), (value: _ReplyFilter.replied, label: 'Replied'), (value: _ReplyFilter.all, label: 'All')],
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(
              child: PagedScroll(
                key: ValueKey(_filter),
                value: ref.watch(provider),
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                empty: EmptyState(
                  icon: Icons.star_outline_rounded,
                  title: _filter == _ReplyFilter.needsReply ? 'You are all caught up' : 'No reviews here yet',
                  message: _filter == _ReplyFilter.needsReply ? 'Reviews waiting for your reply show up here.' : 'Guest reviews of your properties show up here.',
                ),
                itemBuilder: (context, r, _) => SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReviewTile(review: r, showHostel: true),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          AppButton(label: r.ownerReply == null ? 'Reply' : 'Edit reply', icon: Icons.reply_rounded, variant: AppButtonVariant.secondary, expand: false, compact: true, onPressed: () => _reply(r)),
                          if (r.ownerReply != null) AppButton(label: 'Delete reply', variant: AppButtonVariant.ghost, expand: false, compact: true, onPressed: () => _deleteReply(r)),
                          AppButton(label: 'Report', variant: AppButtonVariant.ghost, expand: false, compact: true, onPressed: () => _report(r)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({this.initial});
  final String? initial;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final _text = TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final v = _text.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Write a reply first');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.initial == null ? 'Reply to this review' : 'Edit your reply',
      footer: AppButton(label: widget.initial == null ? 'Post reply' : 'Save reply', onPressed: _send),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your reply is public and shown under the review. Stay polite and specific.', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Reply',
            controller: _text,
            autofocus: true,
            maxLength: 1000,
            minLines: 4,
            maxLines: 8,
            showCounter: true,
            textCapitalization: TextCapitalization.sentences,
            errorText: _error,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}
