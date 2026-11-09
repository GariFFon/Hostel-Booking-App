import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheet.dart';
import '../../bookings/application/booking_providers.dart';
import '../application/review_providers.dart';
import '../data/review_repository.dart';
import '../domain/review_models.dart';

/// Write a review for a completed stay (pass [bookingId]) or edit your own (pass [existing]). Completes with `true` when saved.
Future<bool> showReviewSheet(BuildContext context, {required String hostelName, String? bookingId, Review? existing}) async {
  assert(bookingId != null || existing != null);
  final saved = await showAppSheet<bool>(
    context,
    builder: (_) => ReviewFormSheet(hostelName: hostelName, bookingId: bookingId, existing: existing),
  );
  return saved ?? false;
}

class ReviewFormSheet extends ConsumerStatefulWidget {
  const ReviewFormSheet({super.key, required this.hostelName, this.bookingId, this.existing});
  final String hostelName;
  final String? bookingId;
  final Review? existing;

  @override
  ConsumerState<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<ReviewFormSheet> {
  late int _overall = widget.existing?.overall ?? 0;
  late int? _cleanliness = widget.existing?.cleanliness;
  late int? _location = widget.existing?.location;
  late int? _staff = widget.existing?.staff;
  late int? _value = widget.existing?.valueForMoney;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');
  bool _busy = false;
  String? _error;
  bool _showRatingError = false;

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_overall == 0) {
      setState(() => _showRatingError = true);
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = ReviewDraft(
      overall: _overall,
      cleanliness: _cleanliness,
      location: _location,
      staff: _staff,
      valueForMoney: _value,
      title: _title.text,
      comment: _comment.text,
    );
    try {
      final repo = ref.read(reviewRepositoryProvider);
      if (widget.existing != null) {
        await repo.update(widget.existing!.id, draft);
      } else {
        await repo.create(widget.bookingId!, draft);
      }
      ref.invalidate(myReviewsProvider);
      ref.invalidate(hostelReviewsProvider);
      ref.invalidate(reviewSummaryProvider);
      if (widget.bookingId != null) ref.invalidate(bookingDetailProvider(widget.bookingId!));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
      showToast(context, widget.existing != null ? 'Review updated' : 'Thanks for your review');
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final editing = widget.existing != null;
    return SheetFrame(
      title: editing ? 'Edit your review' : 'Rate your stay',
      footer: AppButton(label: editing ? 'Save changes' : 'Post review', onPressed: _save, loading: _busy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hostelName, style: t.bodyMedium?.copyWith(color: c.mutedForeground), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Text('Overall', style: t.titleSmall),
          const SizedBox(height: 4),
          StarInput(
            value: _overall,
            size: 36,
            label: 'Overall rating',
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      _overall = v;
                      _showRatingError = false;
                    }),
          ),
          if (_showRatingError) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Choose a star rating', style: t.bodySmall?.copyWith(color: c.destructive))),
          const SizedBox(height: 20),
          Text.rich(TextSpan(text: 'Rate the details', style: t.titleSmall, children: [TextSpan(text: '  Optional', style: t.bodySmall)])),
          const SizedBox(height: 4),
          _Category(label: 'Cleanliness', value: _cleanliness, onChanged: _busy ? null : (v) => setState(() => _cleanliness = v)),
          _Category(label: 'Location', value: _location, onChanged: _busy ? null : (v) => setState(() => _location = v)),
          _Category(label: 'Staff', value: _staff, onChanged: _busy ? null : (v) => setState(() => _staff = v)),
          _Category(label: 'Value for money', value: _value, onChanged: _busy ? null : (v) => setState(() => _value = v)),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Headline',
            optional: true,
            controller: _title,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Your review',
            optional: true,
            controller: _comment,
            hint: 'What was it like? Who would you recommend it to?',
            maxLength: 2000,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            showCounter: true,
            enabled: !_busy,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(_error!, style: t.bodyMedium?.copyWith(color: c.destructive))),
            ),
        ],
      ),
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          StarInput(value: value ?? 0, size: 24, label: label, allowClear: true, onChanged: onChanged == null ? null : (v) => onChanged!(v == 0 ? null : v)),
        ],
      ),
    );
  }
}

/// Five tappable stars. Each is a 44 dp target that announces "3 of 5 stars"; [allowClear] lets a second tap on the current
/// rating clear it (for the optional categories).
class StarInput extends StatelessWidget {
  const StarInput({super.key, required this.value, required this.onChanged, this.size = 32, this.label = 'Rating', this.allowClear = false});

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final String label;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Pressable(
              onTap: onChanged == null ? null : () => onChanged!(allowClear && value == i ? 0 : i),
              haptic: true,
              scale: 0.88,
              semanticLabel: '$i of 5 stars',
              minSize: Size(size < kMinTap ? kMinTap * 0.8 : size, kMinTap),
              child: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= value ? c.star : c.mutedForeground.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}
