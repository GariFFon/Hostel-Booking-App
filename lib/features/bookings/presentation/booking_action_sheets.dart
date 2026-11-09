import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../application/booking_providers.dart';

/// Guest cancellation: says exactly what comes back before anything is cancelled. Completes with the (possibly empty)
/// reason once the guest confirms, or `null` if they back out.
Future<({String reason})?> showCancelBookingSheet(BuildContext context, {required String bookingId, required bool paid}) {
  return showAppSheet<({String reason})>(
    context,
    builder: (_) => _CancelSheet(bookingId: bookingId, paid: paid),
  );
}

/// Asks the host for a reason (declining or cancelling a booking). The guest is shown this text.
Future<({String reason})?> showReasonSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String hint = 'Tell the guest why',
  bool required = true,
}) {
  return showAppSheet<({String reason})>(
    context,
    builder: (_) => _ReasonSheet(title: title, message: message, confirmLabel: confirmLabel, hint: hint, required: required),
  );
}

class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet({required this.bookingId, required this.paid});
  final String bookingId;
  final bool paid;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final r = _reason.text.trim();
    if (r.isNotEmpty && r.length < 3) {
      setState(() => _error = 'Use at least 3 characters, or leave it empty');
      return;
    }
    Navigator.of(context).pop((reason: r));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final preview = widget.paid ? ref.watch(cancellationPreviewProvider(widget.bookingId)) : null;

    Widget refundBox() {
      if (preview == null) {
        return Text('Nothing has been charged for this booking.', style: t.bodyMedium?.copyWith(color: c.mutedForeground));
      }
      return preview.when(
        loading: () => const Skeleton(child: SkeletonBox(height: 72, radius: 12)),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(cancellationPreviewProvider(widget.bookingId))),
        data: (p) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text('Refund to you', style: t.bodyMedium)),
                  Text(
                    p.refundPaise == 0 ? '₹0' : money(p.refundPaise),
                    style: t.titleLarge?.copyWith(color: p.refundPaise > 0 ? c.success : null).tabular,
                  ),
                ],
              ),
              if (p.retainedPaise > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text('Kept by the property', style: t.bodySmall)),
                    Text(money(p.retainedPaise), style: t.bodySmall?.tabular),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                p.refundPercent >= 100
                    ? 'Free cancellation: you get everything back.'
                    : p.refundPercent <= 0
                    ? 'This is past the free-cancellation window, so nothing is refunded.'
                    : '${p.refundPercent}% of what you paid is refunded under the cancellation policy.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return SheetFrame(
      title: 'Cancel this booking?',
      footer: Row(
        children: [
          Expanded(
            child: AppButton(label: 'Keep booking', onPressed: () => Navigator.of(context).pop(), variant: AppButtonVariant.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: 'Cancel booking',
              onPressed: preview != null && !preview.hasValue ? null : _confirm,
              variant: AppButtonVariant.destructive,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          refundBox(),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Reason',
            optional: true,
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            errorText: _error,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
          const SizedBox(height: 4),
          Text('This cannot be undone.', style: t.bodySmall),
        ],
      ),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.message, required this.confirmLabel, required this.hint, required this.required});
  final String title;
  final String message;
  final String confirmLabel;
  final String hint;
  final bool required;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final r = _reason.text.trim();
    if (widget.required && r.length < 3) {
      setState(() => _error = 'Add a short reason (at least 3 characters)');
      return;
    }
    Navigator.of(context).pop((reason: r));
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      footer: Row(
        children: [
          Expanded(
            child: AppButton(label: 'Not now', onPressed: () => Navigator.of(context).pop(), variant: AppButtonVariant.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(label: widget.confirmLabel, onPressed: _confirm, variant: AppButtonVariant.destructive),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: context.text.bodyMedium),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Reason',
            optional: !widget.required,
            controller: _reason,
            hint: widget.hint,
            maxLength: 500,
            maxLines: 3,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            errorText: _error,
            autofocus: true,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}
