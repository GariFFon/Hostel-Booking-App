import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/ids.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheet.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import '../domain/payment_models.dart';

/// Opens the demo payment sheet. Completes with `true` once the server has confirmed the booking.
///
/// Mirrors a real gateway: an order is started, the "bank" answers asynchronously (by signed webhook on the server) and the
/// booking only turns CONFIRMED when the server says so. The app never decides that a payment succeeded.
Future<bool> showPaymentSheet(BuildContext context, Booking booking) async {
  final result = await showAppSheet<bool>(
    context,
    dismissible: false, // closing is offered by the sheet itself, except while the bank is being asked
    builder: (_) => PaymentSheet(booking: booking),
  );
  return result ?? false;
}

enum _Phase { choose, processing, confirmed, failed, waiting }

/// 36 polls, 1.1 s apart: about 40 s of patience for the bank before we say "still waiting".
const _maxPolls = 36;
const _pollEvery = Duration(milliseconds: 1100);

const _methods = [
  ('UPI', 'UPI', Icons.smartphone_rounded),
  ('CARD', 'Card', Icons.credit_card_rounded),
  ('NETBANKING', 'Net banking', Icons.account_balance_rounded),
  ('WALLET', 'Wallet', Icons.account_balance_wallet_outlined),
];

const _outcomes = {
  'DEMO_SUCCESS': ('Pay successfully', 'The bank approves right away.'),
  'DEMO_PENDING': ('Takes a moment', 'Like UPI: confirmation arrives a few seconds later.'),
  'DEMO_FAIL': ('Payment fails', 'See what happens when the bank declines.'),
  'DEMO_TIMEOUT': ('Never completes', 'Nothing comes back from the bank.'),
};

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.booking});
  final Booking booking;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  _Phase _phase = _Phase.choose;
  PaymentOrder? _order;
  bool _starting = true;
  String? _error;
  String _instrument = 'DEMO_SUCCESS';
  String _method = 'UPI';
  bool _alive = true;

  Booking get _booking => widget.booking;

  @override
  void initState() {
    super.initState();
    _startOrder();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  /// Starts (or resumes) the payment order. After a failure the server hands out a fresh one, because a failed order is final.
  Future<void> _startOrder() async {
    setState(() {
      _starting = true;
      _order = null;
    });
    try {
      final order = await ref.read(bookingRepositoryProvider).startPayment(_booking.id, idempotencyKey: newIdempotencyKey());
      if (!_alive) return;
      setState(() => _order = order);
    } on ApiException catch (e) {
      if (!_alive) return;
      if (e.status == 409) ref.invalidate(bookingDetailProvider(_booking.id)); // not payable any more: the booking page will say why
      setState(() => _error = e.userMessage);
    } finally {
      if (_alive) setState(() => _starting = false);
    }
  }

  Future<void> _pay() async {
    final order = _order;
    if (order == null) return;
    final repo = ref.read(bookingRepositoryProvider);
    setState(() {
      _phase = _Phase.processing;
      _error = null;
    });

    // Asking the "bank": only a failure *here* means the payment did not go through.
    try {
      await repo.demoCheckout(order.id, instrument: _instrument, method: _method);
    } catch (e) {
      if (!_alive) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _error = errorText(e);
        _phase = _Phase.failed;
      });
      _startOrder();
      return;
    }

    // From here the money may already have moved. The server confirms by webhook, so poll the booking. A problem while *polling*
    // (offline, token trouble, a surprise payload) is never reported as a failed payment: we end in "still waiting".
    try {
      for (var poll = 0; poll < _maxPolls && _alive; poll++) {
        await Future<void>.delayed(_pollEvery);
        if (!_alive) return;
        Booking b;
        try {
          b = await repo.detail(_booking.id);
        } on ApiException catch (e) {
          if (e.isUnauthenticated || e.isForbidden || e.isNotFound) break;
          continue; // a blip: keep asking
        }
        if (!_alive) return;
        if (b.status == BookingStatus.confirmed) {
          ref.invalidate(bookingDetailProvider(_booking.id));
          ref.invalidate(bookingListProvider);
          HapticFeedback.heavyImpact();
          setState(() => _phase = _Phase.confirmed);
          return;
        }
        // Only a failure of *this* order counts: the booking may still show the previous, already-failed attempt.
        if (b.payment?.id == order.id && b.payment?.status.toUpperCase() == 'FAILED') {
          setState(() {
            _error = b.payment?.failureReason ?? 'The bank declined this payment.';
            _phase = _Phase.failed;
          });
          _startOrder();
          return;
        }
        if (b.status != BookingStatus.pendingPayment) {
          // Confirmed-by-approval, expired or cancelled in the meantime: let the booking page explain.
          ref.invalidate(bookingDetailProvider(_booking.id));
          ref.invalidate(bookingListProvider);
          setState(() => _phase = _Phase.waiting);
          return;
        }
      }
    } catch (_) {
      // fall through to "still waiting"
    }
    if (_alive) setState(() => _phase = _Phase.waiting);
  }

  void _close() => Navigator.of(context).pop(_phase == _Phase.confirmed);

  @override
  Widget build(BuildContext context) {
    final processing = _phase == _Phase.processing;
    return PopScope(
      canPop: !processing,
      child: SheetFrame(
        title: _phase == _Phase.confirmed ? 'Payment received' : 'Complete your payment',
        showClose: !processing,
        footer: _phase == _Phase.choose || _phase == _Phase.failed ? _payButton() : null,
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.fade),
          child: KeyedSubtree(key: ValueKey(_phase), child: _body(context)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    switch (_phase) {
      case _Phase.confirmed:
        return _Result(
          icon: Icons.check_circle_rounded,
          color: c.success,
          title: "You're booked",
          message: 'We have emailed your confirmation. Booking ${_booking.code}.',
          primaryLabel: 'View booking',
          onPrimary: _close,
        );
      case _Phase.processing:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Semantics(
            liveRegion: true,
            child: Column(
              children: [
                SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: c.primary)),
                const SizedBox(height: 16),
                Text('Confirming with the bank…', style: t.titleMedium),
                const SizedBox(height: 4),
                Text("Please don't close this window.", style: t.bodyMedium?.copyWith(color: c.mutedForeground)),
              ],
            ),
          ),
        );
      case _Phase.waiting:
        return _Result(
          icon: Icons.schedule_rounded,
          color: c.warning,
          title: 'Still waiting for the bank',
          message: "You haven't been charged twice and your beds are still held. The booking page updates when the payment arrives; if nothing comes through, you can try again.",
          primaryLabel: 'Try again',
          onPrimary: () {
            setState(() {
              _phase = _Phase.choose;
              _error = null;
            });
            if (_order == null && !_starting) _startOrder();
          },
          secondaryLabel: 'Close',
          onSecondary: _close,
        );
      case _Phase.choose:
      case _Phase.failed:
        return _chooser(context);
    }
  }

  Widget _chooser(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final instruments = (_order?.checkout?.instruments.isNotEmpty ?? false) ? _order!.checkout!.instruments : _outcomes.keys.toList();
    final failed = _phase == _Phase.failed;
    String sentence(String s) => RegExp(r'[.!?]$').hasMatch(s.trim()) ? s.trim() : '${s.trim()}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Amount to pay', style: t.bodyMedium?.copyWith(color: c.mutedForeground)),
              ),
              Text(money(_booking.pricing.totalPaise), style: t.headlineSmall?.tabular),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Notice(
          icon: Icons.info_outline_rounded,
          color: c.info,
          title: 'Demo payment',
          text: 'No real money moves. Pick how the “bank” should respond so you can see every outcome.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.error_outline_rounded,
            color: c.destructive,
            title: failed ? "Payment didn't go through" : null,
            text: failed ? '${sentence(_error!)} Your beds are still held. Choose an outcome and try again.' : _error!,
            actionLabel: !failed && _order == null && !_starting ? 'Retry' : null,
            onAction: _startOrder,
          ),
        ],
        const SizedBox(height: 20),
        Text('Pay with', style: t.titleSmall),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.2,
          children: [
            for (final (value, label, icon) in _methods)
              _Choice(
                selected: _method == value,
                onTap: () => setState(() => _method = value),
                semanticLabel: label,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: _method == value ? c.accentForeground : c.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Simulate', style: t.titleSmall),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: Radii.pillR,
                border: Border.all(color: c.input),
              ),
              child: Text('demo', style: t.labelMedium?.copyWith(fontSize: 11, color: c.mutedForeground)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final i in instruments) ...[
          _Choice(
            selected: _instrument == i,
            onTap: () => setState(() => _instrument = i),
            semanticLabel: '${_outcomes[i]?.$1 ?? humanize(i)}. ${_outcomes[i]?.$2 ?? ''}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _instrument == i ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: _instrument == i ? c.primary : c.mutedForeground,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_outcomes[i]?.$1 ?? humanize(i), style: t.titleSmall),
                      if (_outcomes[i] != null) Text(_outcomes[i]!.$2, style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// Pinned under the scrolling body so paying never needs a scroll to reach.
  Widget _payButton() => AppButton(label: 'Pay ${money(_booking.pricing.totalPaise)}', loading: _starting, onPressed: _order == null ? null : _pay);
}

/// A selectable card (payment method or simulated outcome).
class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.onTap, required this.child, required this.semanticLabel});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.985,
        mergeSemantics: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.6) : c.card,
            borderRadius: Radii.baseR,
            border: Border.all(color: selected ? c.primary : c.input, width: selected ? 1.5 : 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text, this.title, this.actionLabel, this.onAction});
  final IconData icon;
  final Color color;
  final String text;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.tint(color),
          borderRadius: Radii.baseR,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: t.titleSmall),
                  Text(text, style: t.bodyMedium),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 6),
                    AppButton(label: actionLabel!, onPressed: onAction, variant: AppButtonVariant.secondary, expand: false, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width outcome (confirmed / still waiting). The icon settles in with a short scale+fade unless reduced motion is on.
class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final reduced = Motion.reduced(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Semantics(
        liveRegion: true,
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : 0.5, end: 1),
              duration: reduced ? Duration.zero : Motion.enter,
              curve: Motion.easeOut,
              builder: (_, v, child) => Opacity(
                opacity: v.clamp(0, 1),
                child: Transform.scale(scale: v, child: child),
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: t.bodyMedium?.copyWith(color: context.colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (secondaryLabel != null && onSecondary != null)
              Row(
                children: [
                  Expanded(
                    child: AppButton(label: secondaryLabel!, onPressed: onSecondary, variant: AppButtonVariant.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(label: primaryLabel, onPressed: onPrimary),
                  ),
                ],
              )
            else
              AppButton(label: primaryLabel, onPressed: onPrimary),
          ],
        ),
      ),
    );
  }
}
