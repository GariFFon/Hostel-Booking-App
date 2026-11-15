import 'package:flutter/material.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheet.dart';
import '../../reviews/presentation/review_form_sheet.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../domain/complaint_models.dart';
import 'availability_widgets.dart';

Tone complaintTone(ComplaintStatus s) => switch (s) {
  ComplaintStatus.resolved => Tone.success,
  ComplaintStatus.open || ComplaintStatus.onHold => Tone.warning,
  ComplaintStatus.reopened || ComplaintStatus.rejected => Tone.danger,
  ComplaintStatus.acknowledged || ComplaintStatus.assigned || ComplaintStatus.inProgress => Tone.info,
  _ => Tone.neutral,
};

Tone priorityTone(ComplaintPriority p) => switch (p) {
  ComplaintPriority.urgent => Tone.danger,
  ComplaintPriority.high => Tone.warning,
  _ => Tone.neutral,
};

String tradeLabel(String? trade) {
  if (trade == null || trade.isEmpty) return '';
  if (trade == 'NETWORK') return 'Wi-Fi / network';
  return humanize(trade);
}

/// One complaint in a list: shared by the tenant's list and a maintenance person's job list.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({super.key, required this.complaint, required this.onTap, this.forStaff = false, this.owner = false});
  final ComplaintSummary complaint;
  final VoidCallback onTap;
  final bool forStaff;

  /// The owner's inbox: shows who raised it and from which bed.
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final x = complaint;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${x.title}, ${x.status.label}',
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(x.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                StatusChip(x.status.label, tone: complaintTone(x.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              owner
                  ? '${x.raisedBy.name ?? 'Tenant'} · bed ${x.unitLabel} · ${x.hostel.name}'
                  : forStaff
                  ? '${x.hostel.name} · bed ${x.unitLabel}${x.location != null ? ' · ${x.location}' : ''}'
                  : '${x.hostel.name} · ${x.category.label}',
              style: t.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (x.priority == ComplaintPriority.urgent || x.priority == ComplaintPriority.high)
                  StatusChip(x.priority.label, tone: priorityTone(x.priority)),
                if (x.slaBreached && x.status.isOpen) const StatusChip('Overdue', tone: Tone.danger),
                Text(x.code, style: t.bodySmall?.copyWith(color: c.mutedForeground)),
                Text(relativeTime(x.createdAt), style: t.bodySmall?.copyWith(color: c.mutedForeground)),
                if (x.visit != null)
                  Text('Visit ${fmtSpan(x.visit!.start, x.visit!.end)}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))
                else if ((forStaff || owner) && x.availability != null && x.status.isOpen)
                  Text('Free ${fmtSpan(x.availability!.from, x.availability!.to)}', style: t.bodySmall?.copyWith(color: c.mutedForeground)),
                if (x.assignedStaff != null && !forStaff)
                  Text('With ${x.assignedStaff!.display}', style: t.bodySmall?.copyWith(color: c.mutedForeground)),
                if (x.rating != null) StarRow(rating: x.rating!, size: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a short note (a reason, or what was done). Resolves to the trimmed text, or null if dismissed.
Future<String?> showNoteSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String label,
  required String confirmLabel,
  String? hint,
  bool required = true,
}) => showAppSheet<String>(
  context,
  builder: (_) => _NoteSheet(title: title, message: message, label: label, confirmLabel: confirmLabel, hint: hint, required: required),
);

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.title, required this.message, required this.label, required this.confirmLabel, this.hint, required this.required});
  final String title;
  final String message;
  final String label;
  final String confirmLabel;
  final String? hint;
  final bool required;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _confirm() {
    final v = _text.text.trim();
    if (widget.required && v.length < 3) {
      setState(() => _error = 'Add a few words (at least 3 characters)');
      return;
    }
    Navigator.of(context).pop(v);
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
            child: AppButton(label: widget.confirmLabel, onPressed: _confirm),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: context.text.bodyMedium),
          const SizedBox(height: 16),
          AppTextField(
            label: widget.label,
            controller: _text,
            hint: widget.hint,
            maxLength: 500,
            maxLines: 3,
            errorText: _error,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}

/// Stars + optional words. Resolves to (rating, feedback), or null if dismissed.
Future<({int rating, String feedback})?> showRateSheet(BuildContext context) =>
    showAppSheet<({int rating, String feedback})>(context, builder: (_) => const _RateSheet());

class _RateSheet extends StatefulWidget {
  const _RateSheet();

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _feedback = TextEditingController();
  int _rating = 0;
  String? _error;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Rate the fix',
      footer: AppButton(
        label: 'Send rating',
        onPressed: () {
          if (_rating == 0) return setState(() => _error = 'Tap a star to rate');
          Navigator.of(context).pop((rating: _rating, feedback: _feedback.text.trim()));
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Was the problem fixed well?', style: context.text.bodyMedium),
          const SizedBox(height: 8),
          StarInput(
            value: _rating,
            onChanged: (v) => setState(() {
              _rating = v;
              _error = null;
            }),
          ),
          if (_error != null) Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.destructive)),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Anything to add?',
            optional: true,
            controller: _feedback,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
