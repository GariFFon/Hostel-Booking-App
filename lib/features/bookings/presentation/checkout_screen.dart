import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/ids.dart';
import '../../../core/util/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';
import '../../hostels/domain/enums.dart';
import '../application/booking_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking_models.dart';
import '../domain/quote_models.dart';
import 'checkout_args.dart';
import 'price_lines.dart';

/// "Review and book": who is staying, how to reach them, a coupon, the itemised price, then one button.
///
/// The booking request carries `expectedTotalPaise`, so a price that moved since the quote is reported
/// (PRICE_CHANGED) instead of silently charged. Retrying the same request reuses one idempotency key, so a double tap
/// or a flaky network can never create two bookings.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.args});

  /// `null` when the app was restarted on this page (go_router `extra` is not restored).
  final CheckoutArgs? args;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _GuestFields {
  final name = TextEditingController();
  final age = TextEditingController();
  String? gender;
  String? genderError;

  void dispose() {
    name.dispose();
    age.dispose();
  }
}

/// Age is optional; when given it must be a sensible whole number.
String? _ageError(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  return n == null || n < 1 || n > 120 ? 'Enter a valid age' : null;
}

enum _BannerTone { warning, danger }

class _Banner {
  const _Banner(this.tone, this.text, {this.actionLabel, this.onAction});
  final _BannerTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  late final List<_GuestFields> _guests;
  late final List<GlobalKey> _guestKeys;
  final _contactKey = GlobalKey();
  String? _coupon;
  bool _busy = false;
  _Banner? _banner;
  Map<String, String> _server = const {};
  ({String body, String key})? _attempt;

  /// Captured once: the pending copy is cleared after booking, and the screen must not flash "expired" while it navigates away.
  late final CheckoutArgs? _args;

  @override
  void initState() {
    super.initState();
    _args = widget.args ?? ref.read(pendingCheckoutProvider);
    final n = _args?.guests ?? 1;
    _guests = List.generate(n, (_) => _GuestFields());
    _guestKeys = List.generate(n, (_) => GlobalKey());
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _guests.first.name.text = user.fullName?.trim() ?? '';
      final digits = (user.phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) _phone.text = digits.substring(digits.length - 10);
    }
  }

  @override
  void dispose() {
    for (final g in _guests) {
      g.dispose();
    }
    _phone.dispose();
    _notes.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Gendered stays (men-only / women-only property, or a gendered dorm) need each guest's gender to be checked.
  bool get _genderRequired {
    final a = _args!;
    if (a.hostel.genderPolicy == GenderPolicy.maleOnly || a.hostel.genderPolicy == GenderPolicy.femaleOnly) return true;
    return a.items.any((i) {
      final g = a.hostel.roomById(i.roomTypeId)?.gender;
      return g == RoomGender.male || g == RoomGender.female;
    });
  }

  QuoteArgs get _quoteArgs {
    final a = _args!;
    return QuoteArgs(hostelId: a.hostel.id, checkIn: a.checkIn, checkOut: a.checkOut, guests: a.guests, items: a.items, couponCode: _coupon);
  }

  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Brings the first guest (or the contact block) that needs attention into view, so the error is never off-screen.
  void _revealFirstProblem() {
    GlobalKey target = _contactKey;
    for (var i = 0; i < _guests.length; i++) {
      final g = _guests[i];
      if (Validators.fullName(g.name.text) != null || _ageError(g.age.text) != null || g.genderError != null) {
        target = _guestKeys[i];
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = target.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.1, curve: Curves.easeOut);
    });
  }

  Future<void> _submit(Quote quote) async {
    if (_busy) return;
    final a = _args!;
    setState(() {
      _banner = null;
      _server = const {};
    });

    final fieldsOk = _form.currentState!.validate();
    var gendersOk = true;
    if (_genderRequired) {
      for (final g in _guests) {
        g.genderError = g.gender == null ? "Select this guest's gender" : null;
        if (g.gender == null) gendersOk = false;
      }
      setState(() {});
    }
    if (!fieldsOk || !gendersOk) {
      HapticFeedback.mediumImpact();
      showToast(context, 'Check the highlighted fields.', error: true);
      _revealFirstProblem();
      return;
    }

    final guests = [for (final g in _guests) GuestInput(fullName: g.name.text, gender: g.gender, age: int.tryParse(g.age.text.trim()))];
    final phone = Validators.normaliseMobile(_phone.text);
    final couponCode = quote.couponApplied ? quote.coupon!.code : null;
    final notes = _notes.text.trim();

    // One idempotency key per distinct request: retrying the same one replays the same booking.
    final fingerprint = jsonEncode({
      'h': a.hostel.id,
      'in': toApiDate(a.checkIn),
      'out': toApiDate(a.checkOut),
      'items': a.items.map((i) => i.toJson()).toList(),
      'guests': guests.map((g) => g.toJson()).toList(),
      'phone': phone,
      'coupon': couponCode,
      'notes': notes,
      'total': quote.totalPaise,
    });
    if (_attempt?.body != fingerprint) _attempt = (body: fingerprint, key: newIdempotencyKey());

    setState(() => _busy = true);
    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .create(
            idempotencyKey: _attempt!.key,
            hostelId: a.hostel.id,
            checkIn: a.checkIn,
            checkOut: a.checkOut,
            items: a.items,
            guests: guests,
            contactPhone: phone,
            couponCode: couponCode,
            specialRequests: notes,
            expectedTotalPaise: quote.totalPaise,
          );
      ref.invalidate(bookingListProvider);
      ref.read(pendingCheckoutProvider.notifier).set(null);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      context.pushReplacement(Routes.booking(booking.id, pay: booking.status == BookingStatus.pendingPayment));
    } on ApiException catch (e) {
      if (!mounted) return;
      _onError(e, a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onError(ApiException e, CheckoutArgs a) {
    HapticFeedback.mediumImpact();
    switch (e.code) {
      case 'PRICE_CHANGED':
        final d = e.details;
        ref.invalidate(quoteProvider);
        final was = d is Map && d['expectedTotalPaise'] is num ? (d['expectedTotalPaise'] as num).toInt() : null;
        final now = d is Map && d['totalPaise'] is num ? (d['totalPaise'] as num).toInt() : null;
        setState(
          () => _banner = _Banner(
            _BannerTone.warning,
            was != null && now != null
                ? 'The price changed from ${money(was)} to ${money(now)}. Review the new total, then confirm again.'
                : e.userMessage,
          ),
        );
      case 'SOLD_OUT':
        ref.invalidate(quoteProvider);
        setState(
          () => _banner = _Banner(
            _BannerTone.danger,
            'Someone just booked the last beds. Pick different dates or rooms.',
            actionLabel: 'Back to the property',
            onAction: () => context.pop(),
          ),
        );
      case 'VALIDATION_FAILED':
        final general = <String>[];
        final mine = <String, String>{};
        for (final entry in e.fieldErrors.entries) {
          if (entry.key == 'contactPhone' || entry.key.startsWith('guests.')) {
            mine[entry.key] = entry.value;
          } else {
            general.add(entry.value);
          }
        }
        setState(() {
          _server = mine;
          _banner = _Banner(_BannerTone.danger, general.isEmpty ? 'Please fix the highlighted fields.' : general.join(' '));
        });
      default:
        setState(() => _banner = _Banner(_BannerTone.danger, e.userMessage));
    }
    _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final a = _args;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'This checkout has expired',
          message: 'Choose your dates and rooms again to continue.',
          actionLabel: 'Back to search',
          onAction: () => context.go(Routes.explore),
        ),
      );
    }

    final c = context.colors;
    final t = context.text;
    final quoteAsync = ref.watch(quoteProvider(_quoteArgs));
    final quote = quoteAsync.value;
    final approval = a.hostel.bookingMode == BookingMode.approval;
    final cta = approval
        ? 'Send request'
        : quote == null
        ? 'Continue'
        : quote.totalPaise == 0
        ? 'Confirm booking'
        : 'Continue to payment · ${money(quote.totalPaise)}';

    return Scaffold(
      appBar: AppBar(title: Text(approval ? 'Request to book' : 'Review and book')),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _form,
              // Not a lazy ListView: `Form.validate()` only reaches fields that are built, and off-screen guests must be validated too.
              child: SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_banner != null) ...[_BannerView(_banner!), const SizedBox(height: 16)],
                    if (approval) ...[
                      const _InfoNote(
                        icon: Icons.hourglass_top_rounded,
                        text: 'This host reviews each request. You pay only if they accept, and you will have time to complete payment.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    _StaySummary(args: a),
                    const SizedBox(height: 24),
                    Text('Who is staying', style: t.titleLarge),
                    const SizedBox(height: 4),
                    Text('Names must match each guest’s ID at check-in.', style: t.bodySmall),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _guests.length; i++) ...[
                      _GuestCard(
                        key: _guestKeys[i],
                        index: i,
                        total: _guests.length,
                        fields: _guests[i],
                        genderRequired: _genderRequired,
                        busy: _busy,
                        nameError: _server['guests.$i.fullName'],
                        ageError: _server['guests.$i.age'],
                        genderServerError: _server['guests.$i.gender'],
                        onGender: (g) => setState(() {
                          _guests[i].gender = g;
                          _guests[i].genderError = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Text('Contact', style: t.titleLarge, key: _contactKey),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Mobile number',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      prefixText: '+91  ',
                      helper: 'The property uses this to reach you about your stay.',
                      validator: Validators.mobile,
                      errorText: _server['contactPhone'],
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Anything the host should know?',
                      optional: true,
                      controller: _notes,
                      hint: 'Arrival time, dietary needs…',
                      maxLength: 500,
                      maxLines: 3,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      showCounter: true,
                      enabled: !_busy,
                      errorText: _server['specialRequests'],
                    ),
                    const SizedBox(height: 24),
                    Text('Coupon', style: t.titleLarge),
                    const SizedBox(height: 12),
                    _CouponBox(
                      applied: _coupon,
                      quote: quoteAsync,
                      busy: _busy,
                      onApply: (code) => setState(() => _coupon = code),
                      onRemove: () => setState(() => _coupon = null),
                    ),
                    const SizedBox(height: 24),
                    Text('Price', style: t.titleLarge),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      child: quoteAsync.when(
                        loading: () => const Skeleton(
                          child: Column(
                            children: [
                              SkeletonBox(height: 16),
                              SizedBox(height: 12),
                              SkeletonBox(height: 16),
                              SizedBox(height: 12),
                              SkeletonBox(height: 24),
                            ],
                          ),
                        ),
                        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(quoteProvider)),
                        data: (q) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PriceBreakdown(
                              lines: quotePriceLines(q),
                              totalPaise: q.totalPaise,
                              note: q.items.any((i) => i.hasSpecialPrice) ? 'Includes weekend or seasonal rates on some nights.' : null,
                            ),
                            if (q.cancellation.summary.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Divider(color: c.border, height: 1),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.event_available_outlined, size: 18, color: c.mutedForeground),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(q.cancellation.summary, style: t.bodySmall)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: c.mutedForeground),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment is simulated in this demo: no real money moves. Your beds are held while you pay.',
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: AppButton(label: cta, loading: _busy, onPressed: quote == null ? null : () => _submit(quote)),
          ),
        ],
      ),
    );
  }
}

class _StaySummary extends StatelessWidget {
  const _StaySummary({required this.args});
  final CheckoutArgs args;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final h = args.hostel;
    final cover = h.gallery.isEmpty ? null : h.gallery.first.thumbUrl;
    final nights = nightsBetween(args.checkIn, args.checkOut);
    return SurfaceCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control),
            child: SizedBox(
              width: 80,
              height: 80,
              child: AppImage(url: cover, cacheWidth: 80, semanticLabel: h.name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (h.address.city.isNotEmpty) Text(h.address.city, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('${fmtRange(args.checkIn, args.checkOut)} · ${plural(nights, 'night')} · ${plural(args.guests, 'guest')}', style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({
    super.key,
    required this.index,
    required this.total,
    required this.fields,
    required this.genderRequired,
    required this.busy,
    required this.onGender,
    this.nameError,
    this.ageError,
    this.genderServerError,
  });

  final int index;
  final int total;
  final _GuestFields fields;
  final bool genderRequired;
  final bool busy;
  final ValueChanged<String> onGender;
  final String? nameError;
  final String? ageError;
  final String? genderServerError;

  static const _genders = [('MALE', 'Male'), ('FEMALE', 'Female'), ('OTHER', 'Other')];

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final err = fields.genderError ?? genderServerError;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total == 1 ? 'Guest' : (index == 0 ? 'Guest 1 (you)' : 'Guest ${index + 1}'), style: t.titleSmall),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Full name',
            controller: fields.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: index == 0 ? const [AutofillHints.name] : null,
            validator: Validators.fullName,
            errorText: nameError,
            maxLength: 100,
            enabled: !busy,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: 'Gender',
              style: t.labelMedium?.copyWith(color: c.foreground),
              children: [if (!genderRequired) TextSpan(text: '  Optional', style: t.bodySmall)],
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            container: true,
            label: 'Gender',
            child: Row(
              children: [
                for (final (value, label) in _genders) ...[
                  Expanded(
                    child: Semantics(
                      inMutuallyExclusiveGroup: true,
                      selected: fields.gender == value,
                      button: true,
                      label: label,
                      excludeSemantics: true,
                      child: Pressable(
                        onTap: busy ? null : () => onGender(value),
                        haptic: true,
                        scale: 0.97,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: fields.gender == value ? c.accent : c.card,
                            borderRadius: Radii.baseR,
                            border: Border.all(
                              color: fields.gender == value ? c.primary : (err != null ? c.destructive : c.input),
                              width: fields.gender == value ? 1.5 : 1,
                            ),
                          ),
                          child: Text(label, style: t.labelMedium?.copyWith(color: fields.gender == value ? c.accentForeground : c.foreground)),
                        ),
                      ),
                    ),
                  ),
                  if (value != 'OTHER') const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(err, style: t.bodySmall?.copyWith(color: c.destructive)),
            ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Age',
            optional: true,
            controller: fields.age,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            validator: _ageError,
            errorText: ageError,
            enabled: !busy,
          ),
        ],
      ),
    );
  }
}

class _CouponBox extends StatefulWidget {
  const _CouponBox({required this.applied, required this.quote, required this.busy, required this.onApply, required this.onRemove});

  final String? applied;
  final AsyncValue<Quote> quote;
  final bool busy;
  final ValueChanged<String> onApply;
  final VoidCallback onRemove;

  @override
  State<_CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends State<_CouponBox> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onApply(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final applied = widget.applied;

    if (applied == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              label: 'Coupon code',
              optional: true,
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _apply(),
              maxLength: 32,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
              enabled: !widget.busy,
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: AppButton(label: 'Apply', onPressed: widget.busy ? null : _apply, variant: AppButtonVariant.secondary, expand: false),
          ),
        ],
      );
    }

    final q = widget.quote;
    final coupon = q.value?.coupon;
    final loading = q.isLoading && !q.hasValue;
    final valid = coupon != null && coupon.valid;
    final fg = loading ? c.mutedForeground : (valid ? c.success : c.destructive);
    final text = loading
        ? 'Checking $applied…'
        : valid
        ? '$applied applied · you save ${money(coupon.discountPaise)}'
        : (coupon?.message ?? 'This code can’t be used for this stay.');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.tint(fg),
        borderRadius: Radii.baseR,
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(loading ? Icons.hourglass_empty_rounded : (valid ? Icons.check_circle_rounded : Icons.error_outline_rounded), size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: t.bodyMedium?.copyWith(color: fg)),
            ),
          ),
          AppButton(label: 'Remove', onPressed: widget.busy ? null : widget.onRemove, variant: AppButtonVariant.ghost, expand: false, compact: true),
        ],
      ),
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView(this.banner);
  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = banner.tone == _BannerTone.warning ? c.warning : c.destructive;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.tint(fg),
          borderRadius: Radii.baseR,
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(banner.tone == _BannerTone.warning ? Icons.warning_amber_rounded : Icons.error_outline_rounded, size: 20, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(banner.text, style: context.text.bodyMedium?.copyWith(color: c.foreground)),
                ),
              ],
            ),
            if (banner.actionLabel != null && banner.onAction != null) ...[
              const SizedBox(height: 8),
              AppButton(label: banner.actionLabel!, onPressed: banner.onAction, variant: AppButtonVariant.secondary, expand: false, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.tint(c.info),
        borderRadius: Radii.baseR,
        border: Border.all(color: c.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.info),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
