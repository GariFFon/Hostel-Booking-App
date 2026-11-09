import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/launcher.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/countdown.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../host/application/host_providers.dart';
import '../../reviews/presentation/review_form_sheet.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import 'booking_action_sheets.dart';
import 'payment_sheet.dart';
import 'price_lines.dart';

/// One booking, for the guest (`/trips/:id`) or the host (`/host/bookings/:id`). What you can do comes from the server's
/// `actions` list, never from guessing off the status, so the two views and the backend rules cannot drift apart.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.id, this.host = false, this.autoPay = false});

  final String id;
  final bool host;

  /// Open the payment sheet straight away (arriving from checkout).
  final bool autoPay;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  BookingAction? _busy;
  bool _autoPayHandled = false;

  AsyncValue<Booking> _watchDetail() => widget.host ? ref.watch(hostBookingDetailProvider(widget.id)) : ref.watch(bookingDetailProvider(widget.id));

  void _invalidateDetail() => widget.host ? ref.invalidate(hostBookingDetailProvider(widget.id)) : ref.invalidate(bookingDetailProvider(widget.id));

  Future<Booking> _detailFuture() =>
      widget.host ? ref.read(hostBookingDetailProvider(widget.id).future) : ref.read(bookingDetailProvider(widget.id).future);

  void _refresh() {
    if (!mounted) return; // the screen can be popped while a sheet or request is still pending
    _invalidateDetail();
    ref.invalidate(bookingListProvider);
    ref.invalidate(hostBookingsProvider);
  }

  Future<void> _run(BookingAction action, Booking b) async {
    if (_busy != null) return;
    final host = ref.read(hostRepositoryProvider);
    final guest = ref.read(bookingRepositoryProvider);
    try {
      switch (action) {
        case BookingAction.pay:
          setState(() => _busy = action); // a second tap must not stack a second payment sheet
          final paid = await showPaymentSheet(context, b);
          if (paid && mounted) showToast(context, 'Booking confirmed');
          _refresh();
          return;
        case BookingAction.review:
          setState(() => _busy = action);
          await showReviewSheet(context, hostelName: b.hostel.name, bookingId: b.id);
          _refresh();
          return;
        case BookingAction.cancel:
          if (widget.host) {
            final r = await showReasonSheet(
              context,
              title: 'Cancel this booking?',
              message: 'The guest is notified and refunded in full. Cancelling confirmed stays often can hurt your listing.',
              confirmLabel: 'Cancel booking',
            );
            if (r == null) return;
            setState(() => _busy = action);
            await host.cancel(b.id, r.reason);
          } else {
            final r = await showCancelBookingSheet(context, bookingId: b.id, paid: b.payment?.status.toUpperCase() == 'CAPTURED');
            if (r == null) return;
            setState(() => _busy = action);
            await guest.cancel(b.id, reason: r.reason);
          }
        case BookingAction.reject:
          final r = await showReasonSheet(
            context,
            title: 'Decline this request?',
            message: 'The guest is told your reason and nothing is charged.',
            confirmLabel: 'Decline',
          );
          if (r == null) return;
          setState(() => _busy = action);
          await host.reject(b.id, r.reason);
        case BookingAction.approve:
          if (!await _confirm('Accept this request?', 'The guest then has time to pay to confirm the stay.', 'Accept', 'Not yet')) return;
          setState(() => _busy = action);
          await host.approve(b.id);
        case BookingAction.checkIn:
          setState(() => _busy = action);
          await host.checkIn(b.id);
        case BookingAction.complete:
          if (!await _confirm('Mark as completed?', 'This closes the stay and lets the guest review it.', 'Mark completed', 'Not yet')) return;
          setState(() => _busy = action);
          await host.complete(b.id);
        case BookingAction.noShow:
          if (!await _confirm('Mark as no-show?', 'Use this when the guest never arrived.', 'Mark no-show', 'Not yet', destructive: true)) return;
          setState(() => _busy = action);
          await host.noShow(b.id);
        case BookingAction.unknown:
          return;
      }
      HapticFeedback.lightImpact();
      _refresh();
      if (mounted) showToast(context, _doneMessage(action));
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
      _refresh(); // the booking may have changed under us (expired, already decided): show the truth
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _confirm(String title, String message, String confirmLabel, String cancelLabel, {bool destructive = false}) =>
      confirmAction(context, title: title, message: message, confirmLabel: confirmLabel, cancelLabel: cancelLabel, destructive: destructive);

  String _doneMessage(BookingAction a) => switch (a) {
    BookingAction.cancel => 'Booking cancelled',
    BookingAction.reject => 'Request declined',
    BookingAction.approve => 'Request accepted',
    BookingAction.checkIn => 'Marked as checked in',
    BookingAction.complete => 'Stay completed',
    BookingAction.noShow => 'Marked as no-show',
    _ => 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final detail = _watchDetail();
    final back = widget.host ? Routes.host : Routes.trips;

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.code ?? 'Booking'),
        leading: context.canPop() ? null : BackButton(onPressed: () => context.go(back)),
        actions: [
          if (detail.value != null)
            AppIconButton(
              icon: Icons.copy_rounded,
              label: 'Copy booking code',
              size: 20,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: detail.value!.code));
                HapticFeedback.selectionClick();
                showToast(context, 'Booking code copied');
              },
            ),
        ],
      ),
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorState(error: e, onRetry: _invalidateDetail),
        data: (b) {
          if (widget.autoPay && !_autoPayHandled && b.can(BookingAction.pay)) {
            _autoPayHandled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _run(BookingAction.pay, b);
            });
          }
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: () async {
                    _refresh();
                    await _detailFuture();
                  },
                  child: _Body(booking: b, host: widget.host, onElapsed: _refresh),
                ),
              ),
              _ActionBar(booking: b, host: widget.host, busy: _busy, onAction: (a) => _run(a, b)),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.host, required this.onElapsed});
  final Booking booking;
  final bool host;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final t = context.text;
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Hero(booking: b),
        const SizedBox(height: 16),
        _StatusBanner(booking: b, host: host, onElapsed: onElapsed),
        const SizedBox(height: 24),
        _Section(
          title: 'Your stay',
          child: SurfaceCard(
            child: Column(
              children: [
                _Fact(icon: Icons.login_rounded, label: 'Check-in', value: '${fmtDay(b.checkIn)} · from ${fmtClock(b.hostel.checkInTime)}'),
                _Fact(icon: Icons.logout_rounded, label: 'Check-out', value: '${fmtDay(b.checkOut)} · by ${fmtClock(b.hostel.checkOutTime)}'),
                _Fact(icon: Icons.nights_stay_outlined, label: 'Length', value: plural(b.nights, 'night')),
                _Fact(icon: Icons.group_outlined, label: 'Guests', value: plural(b.guestsCount, 'guest'), last: true),
              ],
            ),
          ),
        ),
        if (host && b.guest != null) ...[
          const SizedBox(height: 24),
          _Section(
            title: 'Guest',
            child: _GuestContactCard(guest: b.guest!, confirmed: b.status.isLive && !b.status.isPending),
          ),
        ],
        const SizedBox(height: 24),
        _Section(
          title: 'Where',
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.hostel.name, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(b.hostel.address, style: t.bodyMedium?.copyWith(color: c.mutedForeground)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppButton(
                      label: 'Directions',
                      icon: Icons.directions_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      compact: true,
                      onPressed: () async {
                        final ok = await openMaps(b.hostel.location.latitude, b.hostel.location.longitude, label: b.hostel.name);
                        if (!ok && context.mounted) showToast(context, 'No maps app available', error: true);
                      },
                    ),
                    if (!host && b.hostel.phone != null && b.hostel.phone!.isNotEmpty)
                      AppButton(
                        label: 'Call property',
                        icon: Icons.call_outlined,
                        variant: AppButtonVariant.secondary,
                        expand: false,
                        compact: true,
                        onPressed: () async {
                          final ok = await callPhone(b.hostel.phone!);
                          if (!ok && context.mounted) showToast(context, "Can't place a call from this device", error: true);
                        },
                      ),
                  ],
                ),
                if (!host && b.hostel.phone == null && b.status.isPending) ...[
                  const SizedBox(height: 10),
                  Text("The property's phone number appears once your booking is confirmed.", style: t.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Guests',
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < b.guests.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == b.guests.length - 1 ? 0 : 10),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 20, color: c.mutedForeground),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [
                              b.guests[i].fullName,
                              if (b.guests[i].age != null) '${b.guests[i].age}',
                              if (b.guests[i].gender != null) humanize(b.guests[i].gender!),
                            ].join(' · '),
                            style: t.bodyMedium,
                          ),
                        ),
                        if (b.guests[i].isPrimary) const InfoPill('Booker'),
                      ],
                    ),
                  ),
                if (b.contactPhone != null && b.contactPhone!.isNotEmpty) ...[
                  if (b.guests.isNotEmpty) Divider(color: c.border, height: 24),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 20, color: c.mutedForeground),
                      const SizedBox(width: 10),
                      Expanded(child: Text(b.contactPhone!, style: t.bodyMedium)),
                    ],
                  ),
                ],
                if (b.specialRequests != null && b.specialRequests!.isNotEmpty) ...[
                  Divider(color: c.border, height: 24),
                  Text('Notes for the host', style: t.labelMedium),
                  const SizedBox(height: 2),
                  Text(b.specialRequests!, style: t.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Payment',
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriceBreakdown(lines: bookingPriceLines(b), totalPaise: b.pricing.totalPaise),
                if (b.payment != null) ...[Divider(color: c.border, height: 24), _PaymentLine(payment: b.payment!)],
                if (b.refund != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.undo_rounded, size: 18, color: c.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${money(b.refund!.amountPaise)} refund · ${b.refund!.isSettled ? 'sent back' : 'on its way'}',
                          style: t.bodyMedium?.copyWith(color: c.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (host && b.ownerShare != null) ...[
          const SizedBox(height: 24),
          _Section(
            title: 'Your earnings',
            child: SurfaceCard(
              child: Column(
                children: [
                  _MoneyRow('Platform commission', b.ownerShare!.commissionPaise),
                  const SizedBox(height: 8),
                  _MoneyRow('You receive', b.ownerShare!.ownerNetPaise, bold: true),
                ],
              ),
            ),
          ),
        ],
        if (!host && b.cancellation != null && b.status.isLive) ...[
          const SizedBox(height: 24),
          _Section(
            title: 'Cancellation',
            child: _CancellationCard(state: b.cancellation!),
          ),
        ],
        if (b.timeline.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Section(
            title: 'History',
            child: _Timeline(events: b.timeline),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title), child]);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final b = booking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Radii.cardR,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: AppImage(url: b.hostel.coverUrl, semanticLabel: b.hostel.name),
          ),
        ),
        const SizedBox(height: 12),
        Text(b.hostel.name, style: t.headlineSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        BookingStatusChip(b.status), // under the title, not beside it: a long name plus large text leaves no room for a side-by-side chip
        const SizedBox(height: 6),
        Text(
          '${fmtRange(b.checkIn, b.checkOut)} · ${plural(b.nights, 'night')}${b.hostel.city.isEmpty ? '' : ' · ${b.hostel.city}'}',
          style: t.bodyMedium?.copyWith(color: context.colors.mutedForeground),
        ),
      ],
    );
  }
}

/// Says what is happening and what is expected next, in words.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.booking, required this.host, required this.onElapsed});
  final Booking booking;
  final bool host;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = booking;

    Widget banner(Tone tone, IconData icon, String title, String? body) {
      final fg = switch (tone) {
        Tone.success => c.success,
        Tone.warning => c.warning,
        Tone.danger => c.destructive,
        Tone.info => c.info,
        Tone.neutral => c.mutedForeground,
      };
      return Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tone == Tone.neutral ? c.muted : c.tint(fg),
            borderRadius: Radii.baseR,
            border: Border.all(color: fg.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    if (body != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(body, style: context.text.bodyMedium),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (b.status) {
      case BookingStatus.hold:
      case BookingStatus.pendingPayment:
        if (host) {
          return banner(Tone.warning, Icons.hourglass_top_rounded, 'Waiting for payment', 'The guest has not paid yet. The beds are held for them.');
        }
        if (b.holdExpiresAt == null) return banner(Tone.warning, Icons.payments_outlined, 'Payment due', 'Pay to confirm your stay.');
        return Countdown(
          until: b.holdExpiresAt!,
          onElapsed: onElapsed,
          builder: (_, remaining) => remaining == Duration.zero
              ? banner(
                  Tone.danger,
                  Icons.timer_off_outlined,
                  'Your hold has expired',
                  'The beds were released. You can book again if they are still free.',
                )
              : banner(Tone.warning, Icons.timer_outlined, 'Pay within ${fmtCountdown(remaining)}', 'Your beds are held until then.'),
        );
      case BookingStatus.pendingApproval:
        final by = b.approvalDeadline == null ? '' : ' by ${fmtDateTime(b.approvalDeadline!)}';
        return host
            ? banner(Tone.warning, Icons.mark_email_unread_outlined, 'Needs your decision', 'Accept or decline$by.')
            : banner(
                Tone.warning,
                Icons.hourglass_top_rounded,
                'Waiting for the host',
                'They will accept or decline$by. You are only charged if they accept.',
              );
      case BookingStatus.confirmed:
        return host
            ? banner(
                Tone.success,
                Icons.check_circle_outline_rounded,
                'Confirmed',
                'Payment received. The guest is expected on ${fmtDay(b.checkIn)}.',
              )
            : banner(
                Tone.success,
                Icons.check_circle_outline_rounded,
                "You're booked",
                'Show booking code ${b.code} at check-in on ${fmtDay(b.checkIn)}.',
              );
      case BookingStatus.checkedIn:
        return banner(
          Tone.success,
          Icons.hotel_outlined,
          host ? 'Guest checked in' : 'Enjoy your stay',
          b.checkedInAt == null ? null : 'Checked in ${fmtDateTime(b.checkedInAt!)}.',
        );
      case BookingStatus.completed:
        return banner(
          Tone.info,
          Icons.flag_outlined,
          host ? 'Stay completed' : 'Stay completed',
          host ? null : (b.reviewId != null ? 'Thanks for your review.' : 'How was it? Your review helps other travellers.'),
        );
      case BookingStatus.expired:
        return banner(Tone.neutral, Icons.timer_off_outlined, 'Expired', 'This booking was not paid in time, so the beds were released.');
      case BookingStatus.rejected:
        return banner(Tone.danger, Icons.block_rounded, host ? 'You declined this request' : 'The host declined', b.cancelReason);
      case BookingStatus.cancelledByGuest:
      case BookingStatus.cancelledByOwner:
        final who = b.status == BookingStatus.cancelledByOwner
            ? (host ? 'You cancelled this booking' : 'The host cancelled this booking')
            : (host ? 'The guest cancelled' : 'You cancelled this booking');
        return banner(Tone.danger, Icons.cancel_outlined, who, b.cancelReason);
      case BookingStatus.noShow:
        return banner(Tone.danger, Icons.person_off_outlined, 'Marked as no-show', null);
      case BookingStatus.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(value, style: t.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.paise, {this.bold = false});
  final String label;
  final int paise;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Row(
      children: [
        Expanded(child: Text(label, style: bold ? t.titleSmall : t.bodyMedium)),
        Text(money(paise), style: (bold ? t.titleMedium : t.bodyMedium)?.tabular),
      ],
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.payment});
  final PaymentSummary payment;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final status = payment.status.toUpperCase();
    final (tone, label) = switch (status) {
      'CAPTURED' => (Tone.success, 'Paid'),
      'PARTIALLY_REFUNDED' => (Tone.info, 'Partly refunded'),
      'REFUNDED' => (Tone.info, 'Refunded'),
      'FAILED' => (Tone.danger, 'Failed'),
      'PENDING' => (Tone.warning, 'Processing'),
      _ => (Tone.neutral, humanize(payment.status)),
    };
    return Row(
      children: [
        Icon(Icons.receipt_long_outlined, size: 20, color: c.mutedForeground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            payment.capturedAt != null
                ? 'Paid ${fmtDateTime(payment.capturedAt!)}${payment.method == null ? '' : ' · ${humanize(payment.method!)}'}'
                : (payment.failureReason ?? 'Payment'),
            style: t.bodyMedium,
          ),
        ),
        StatusChip(label, tone: tone),
      ],
    );
  }
}

class _CancellationCard extends StatelessWidget {
  const _CancellationCard({required this.state});
  final CancellationState state;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.summary.isNotEmpty) Text(state.summary, style: t.bodyMedium),
          if (state.freeCancellationUntil != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_available_outlined, size: 18, color: c.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free cancellation until ${fmtDateTime(state.freeCancellationUntil!)}',
                    style: t.bodyMedium?.copyWith(color: c.success),
                  ),
                ),
              ],
            ),
          ],
          if (state.refundPaiseNow > 0) ...[
            const SizedBox(height: 8),
            Text('If you cancel now you get ${money(state.refundPaiseNow)} back (${state.refundPercentNow}%).', style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _GuestContactCard extends StatelessWidget {
  const _GuestContactCard({required this.guest, required this.confirmed});
  final GuestContact guest;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final hasPhone = guest.phone != null && guest.phone!.isNotEmpty;
    final hasEmail = guest.email != null && guest.email!.isNotEmpty;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guest.name?.isNotEmpty == true ? guest.name! : 'Guest', style: t.titleSmall),
          if (!hasPhone && !hasEmail)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Contact details appear once the booking is confirmed.', style: t.bodySmall?.copyWith(color: c.mutedForeground)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasPhone)
                    AppButton(
                      label: 'Call',
                      icon: Icons.call_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      compact: true,
                      onPressed: () => callPhone(guest.phone!),
                    ),
                  if (hasEmail)
                    AppButton(
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      compact: true,
                      onPressed: () => openEmail(guest.email!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        const SizedBox(height: 5),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: i == events.length - 1 ? c.primary : c.input),
                        ),
                        if (i != events.length - 1) Expanded(child: Container(width: 2, color: c.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == events.length - 1 ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(events[i].status.label, style: t.titleSmall),
                          Text(
                            '${fmtDateTime(events[i].at)}${events[i].actorRole == null ? '' : ' · ${humanize(events[i].actorRole!)}'}',
                            style: t.bodySmall,
                          ),
                          if (events[i].reason != null && events[i].reason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(events[i].reason!, style: t.bodyMedium),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Primary action filled, the rest as quiet text buttons underneath. Driven only by `booking.actions`.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.booking, required this.host, required this.busy, required this.onAction});
  final Booking booking;
  final bool host;
  final BookingAction? busy;
  final ValueChanged<BookingAction> onAction;

  static const _primaryOrder = [BookingAction.pay, BookingAction.approve, BookingAction.checkIn, BookingAction.complete, BookingAction.review];
  static const _secondaryOrder = [BookingAction.reject, BookingAction.cancel, BookingAction.noShow];

  String _label(BookingAction a) => switch (a) {
    BookingAction.pay => 'Pay ${money(booking.pricing.totalPaise)}',
    BookingAction.approve => 'Accept request',
    BookingAction.checkIn => 'Mark checked in',
    BookingAction.complete => 'Mark completed',
    BookingAction.review => 'Write a review',
    BookingAction.reject => 'Decline',
    BookingAction.cancel => 'Cancel booking',
    BookingAction.noShow => 'Mark no-show',
    BookingAction.unknown => '',
  };

  @override
  Widget build(BuildContext context) {
    final primary = _primaryOrder.where(booking.can).toList();
    final secondary = _secondaryOrder.where(booking.can).toList();
    if (primary.isEmpty && secondary.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (primary.isNotEmpty)
            AppButton(label: _label(primary.first), loading: busy == primary.first, onPressed: busy == null ? () => onAction(primary.first) : null),
          if (secondary.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: primary.isEmpty ? 0 : 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final a in secondary)
                    AppButton(
                      label: _label(a),
                      loading: busy == a,
                      onPressed: busy == null ? () => onAction(a) : null,
                      variant: primary.isEmpty ? AppButtonVariant.destructive : AppButtonVariant.ghost,
                      expand: primary.isEmpty && secondary.length == 1,
                      compact: primary.isNotEmpty,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(height: double.infinity, radius: 16),
            ),
            SizedBox(height: 14),
            SkeletonBox(width: 240, height: 22),
            SizedBox(height: 8),
            SkeletonBox(width: 160, height: 14),
            SizedBox(height: 20),
            SkeletonBox(height: 64, radius: 12),
            SizedBox(height: 24),
            SkeletonBox(height: 140, radius: 16),
          ],
        ),
      ),
    );
  }
}
