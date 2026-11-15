import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/states.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'availability_widgets.dart';
import 'complaint_widgets.dart';
import 'owner_complaint_sheets.dart';
import 'photo_widgets.dart';

/// A complaint's whole story, for the tenant who filed it or the maintenance person it is assigned to. Buttons are exactly
/// the actions the server says this person may take right now (`actions`); the screen never decides permissions itself.
class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.id, this.staff = false});
  final String id;
  final bool staff;

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _comment = TextEditingController();
  bool _internal = false;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(complaintDetailProvider(widget.id));
    // Whichever list this complaint is on (the tenant's, the staff member's or the owner's inbox) must show the new state.
    ref.invalidate(myComplaintsProvider);
    ref.invalidate(staffJobsProvider);
    ref.invalidate(hostComplaintsProvider);
    if (widget.staff) ref.invalidate(staffMeProvider);
  }

  /// Runs one server action, then shows the result. Errors are shown in words; the screen stays where it is.
  Future<void> _run(Future<Object?> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Which API a button talks to depends on who is looking, as the server reports it (not on how the screen was opened).
  Future<Object?> _act(Map<String, Object?> body) {
    final repo = ref.read(complaintRepositoryProvider);
    final viewer = ref.read(complaintDetailProvider(widget.id)).value?.viewer ?? (widget.staff ? 'STAFF' : 'TENANT');
    return switch (viewer) {
      'OWNER' => repo.ownerAction(widget.id, body),
      'STAFF' => repo.staffAction(widget.id, body),
      _ => repo.tenantAction(widget.id, body),
    };
  }

  Future<void> _assign(ComplaintDetail c) async {
    final id = await showAssignSheet(context, c);
    if (id == null || !mounted) return;
    await _run(() => _act({'action': 'assign', 'staffUserId': id}), 'Assigned');
  }

  Future<void> _unassign() async {
    final ok = await confirmAction(
      context,
      title: 'Take this back?',
      message: 'It returns to your inbox with nobody assigned.',
      confirmLabel: 'Take back',
      cancelLabel: 'Keep',
    );
    if (!ok || !mounted) return;
    await _run(() => _act({'action': 'unassign'}), 'Taken back');
  }

  Future<void> _reject() async {
    final why = await showNoteSheet(
      context,
      title: 'Decline this complaint',
      message: 'The tenant is told why. This cannot be undone.',
      label: 'Reason',
      confirmLabel: 'Decline',
    );
    if (why == null || !mounted) return;
    await _run(() => _act({'action': 'reject', 'reason': why}), 'Complaint declined');
  }

  Future<void> _priority(ComplaintDetail c) async {
    final p = await showPrioritySheet(context, c.priority);
    if (p == null || !mounted) return;
    await _run(() => _act({'action': 'priority', 'priority': p.name.toUpperCase()}), 'Priority changed');
  }

  Future<void> _reopen() async {
    final why = await showNoteSheet(
      context,
      title: 'It isn’t fixed',
      message: 'Tell us what is still wrong. It goes back to the owner.',
      label: 'What is still wrong?',
      confirmLabel: 'Next',
    );
    if (why == null || !mounted) return;
    final free = await showFreeTimeSheet(
      context,
      title: 'When can someone come back?',
      message: 'Choose a time you are free for the second visit.',
      confirmLabel: 'Reopen',
    );
    if (free == null || !mounted) return;
    await _run(() => _act(_withWindow({'action': 'reopen', 'reason': why}, free)), 'Complaint reopened');
  }

  Map<String, Object?> _withWindow(Map<String, Object?> body, FreeTime f) => {
    ...body,
    'availableFrom': f.start.toUtc().toIso8601String(),
    'availableTo': f.end.toUtc().toIso8601String(),
    'allowEntryIfAway': f.allowEntry,
  };

  Future<void> _changeFreeTime() async {
    final free = await showFreeTimeSheet(context);
    if (free == null || !mounted) return;
    await _run(() => _act(_withWindow({'action': 'set_availability'}, free)), 'Free time updated');
  }

  Future<void> _schedule(ComplaintDetail c) async {
    final slot = await showVisitSheet(context, c);
    if (slot == null || !mounted) return;
    await _run(
      () => _act({'action': 'schedule', 'visitStart': slot.start.toUtc().toIso8601String(), 'visitEnd': slot.end.toUtc().toIso8601String()}),
      'Visit booked. The tenant has been told.',
    );
  }

  Future<void> _rate() async {
    final r = await showRateSheet(context);
    if (r == null || !mounted) return;
    await _run(() => _act({'action': 'rate', 'rating': r.rating, if (r.feedback.isNotEmpty) 'feedback': r.feedback}), 'Thanks for the feedback');
  }

  Future<void> _close(ComplaintDetail c) async {
    final resolved = c.status == ComplaintStatus.resolved;
    final ok = await confirmAction(
      context,
      title: resolved ? 'Close this complaint?' : 'Withdraw this complaint?',
      message: resolved ? 'You can still rate the fix afterwards.' : 'Nobody will work on it any more.',
      confirmLabel: resolved ? 'Close' : 'Withdraw',
      cancelLabel: 'Keep open',
    );
    if (!ok || !mounted) return;
    await _run(() => _act({'action': 'close'}), 'Complaint closed');
  }

  Future<void> _hold() async {
    final why = await showNoteSheet(
      context,
      title: 'Put on hold',
      message: 'The tenant and owner will see why.',
      label: 'Why?',
      hint: 'Waiting for a spare part…',
      confirmLabel: 'Put on hold',
    );
    if (why == null || !mounted) return;
    await _run(() => _act({'action': 'hold', 'reason': why}), 'On hold');
  }

  Future<void> _resolve() async {
    final note = await showNoteSheet(
      context,
      title: 'Mark as resolved',
      message: 'Say what you did. The tenant is asked to confirm it is fixed.',
      label: 'What was done?',
      confirmLabel: 'Resolved',
    );
    if (note == null || !mounted) return;
    await _run(() => _act({'action': 'resolve', 'note': note}), 'Marked resolved');
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await ref.read(complaintRepositoryProvider).comment(widget.id, text, internal: _internal);
      _comment.clear();
      _internal = false;
      return null;
    }, 'Comment posted');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(complaintDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(async.value?.code ?? 'Complaint')),
      body: async.when(
        loading: () => const CardSkeletonList(count: 2),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(complaintDetailProvider(widget.id))),
        data: (c) => RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(complaintDetailProvider(widget.id));
            await ref.read(complaintDetailProvider(widget.id).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Header(c: c),
              const SizedBox(height: 12),
              _Actions(
                c: c,
                busy: _busy,
                onStart: () => _run(() => _act({'action': 'start'}), c.status == ComplaintStatus.onHold ? 'Resumed' : 'Started'),
                onHold: _hold,
                onResolve: _resolve,
                onReopen: _reopen,
                onRate: _rate,
                onClose: () => _close(c),
                onSchedule: () => _schedule(c),
                onFreeTime: _changeFreeTime,
                onAcknowledge: () => _run(() => _act({'action': 'acknowledge'}), 'Marked as seen'),
                onAssign: () => _assign(c),
                onUnassign: _unassign,
                onReject: _reject,
                onPriority: () => _priority(c),
              ),
              if (c.media.isNotEmpty || c.can('add_photo')) ...[
                const SectionTitle('Photos'),
                if (c.media.isNotEmpty) ComplaintPhotos(c.media),
                if (c.can('add_photo'))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AddPhotosButton(complaintId: widget.id, have: c.media.length, onAdded: _refresh),
                  ),
              ],
              const SectionTitle('Progress'),
              _Timeline(c.history),
              const SectionTitle('Comments'),
              _Comments(c.comments),
              if (c.can('comment')) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Add a comment',
                  controller: _comment,
                  maxLength: 1000,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (c.viewer == 'OWNER' || c.viewer == 'STAFF')
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible to staff and owner only'),
                    subtitle: const Text('The tenant will not see this note'),
                    value: _internal,
                    onChanged: (v) => setState(() => _internal = v),
                  ),
                const SizedBox(height: 8),
                AppButton(label: 'Post comment', onPressed: _busy ? null : _send, variant: AppButtonVariant.secondary, loading: _busy, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final ComplaintDetail c;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final colors = context.colors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.title, style: t.titleLarge),
          const SizedBox(height: 4),
          Text('${c.hostel.name} · bed ${c.unitLabel}${c.location != null ? ' · ${c.location}' : ''}', style: t.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(c.status.label, tone: complaintTone(c.status)),
              StatusChip(c.priority.label, tone: priorityTone(c.priority)),
              StatusChip(c.category.label),
              if (c.slaBreached && c.status.isOpen) const StatusChip('Overdue', tone: Tone.danger),
            ],
          ),
          if (c.status.isOpen && !c.slaBreached) ...[
            const SizedBox(height: 8),
            Text('Respond by ${fmtDateTime(c.slaDueAt)}', style: t.bodySmall?.copyWith(color: colors.mutedForeground)),
          ],
          const SizedBox(height: 12),
          Text(c.description, style: t.bodyMedium),
          const SizedBox(height: 12),
          if (c.availability != null)
            _Row(
              c.viewer == 'TENANT' ? 'Your free time' : 'Tenant is free',
              '${fmtSpan(c.availability!.from, c.availability!.to)} · ${c.availability!.allowEntryIfAway ? 'staff may go in if nobody is home' : 'someone will be home'}',
            ),
          if (c.visit != null)
            _Row('Visit booked', fmtSpan(c.visit!.start, c.visit!.end))
          else if (c.can('schedule'))
            const _Row('Visit', 'Not booked yet'),
          _Row(
            'Assigned to',
            c.assignedStaff == null
                ? 'Nobody yet'
                : '${c.assignedStaff!.display}${c.assignedStaff!.trade != null ? ' (${tradeLabel(c.assignedStaff!.trade)})' : ''}',
          ),
          if (c.viewer != 'TENANT') _Row('Raised by', '${c.raisedBy.name ?? 'Tenant'}${c.raisedBy.phone != null ? ' · ${c.raisedBy.phone}' : ''}'),
          if (c.resolutionNote != null) _Row('How it was resolved', c.resolutionNote!),
          if (c.rating != null) ...[
            _Row('Your rating', c.feedback ?? ''),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: StarRow(rating: c.rating!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: context.text.bodySmall?.copyWith(color: context.colors.mutedForeground)),
          ),
          Expanded(child: Text(value, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.c,
    required this.busy,
    required this.onStart,
    required this.onHold,
    required this.onResolve,
    required this.onReopen,
    required this.onRate,
    required this.onClose,
    required this.onSchedule,
    required this.onFreeTime,
    required this.onAcknowledge,
    required this.onAssign,
    required this.onUnassign,
    required this.onReject,
    required this.onPriority,
  });
  final ComplaintDetail c;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onHold;
  final VoidCallback onResolve;
  final VoidCallback onReopen;
  final VoidCallback onRate;
  final VoidCallback onClose;
  final VoidCallback onSchedule;
  final VoidCallback onFreeTime;
  final VoidCallback onAcknowledge;
  final VoidCallback onAssign;
  final VoidCallback onUnassign;
  final VoidCallback onReject;
  final VoidCallback onPriority;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (c.can('acknowledge'))
        AppButton(
          label: 'Mark as seen',
          onPressed: busy ? null : onAcknowledge,
          variant: AppButtonVariant.secondary,
          icon: Icons.visibility_outlined,
        ),
      if (c.can('assign'))
        AppButton(
          label: c.assignedStaff == null ? 'Assign to staff' : 'Reassign',
          onPressed: busy ? null : onAssign,
          icon: Icons.person_add_alt_1_outlined,
        ),
      if (c.can('schedule'))
        AppButton(
          label: c.visit == null ? 'Book a visit' : 'Change visit time',
          onPressed: busy ? null : onSchedule,
          variant: c.visit == null ? AppButtonVariant.primary : AppButtonVariant.secondary,
          icon: Icons.event_available_outlined,
        ),
      if (c.can('set_availability'))
        AppButton(
          label: 'Change my free time',
          onPressed: busy ? null : onFreeTime,
          variant: AppButtonVariant.secondary,
          icon: Icons.schedule_rounded,
        ),
      if (c.can('start'))
        AppButton(
          label: c.status == ComplaintStatus.onHold ? 'Resume work' : 'Start work',
          onPressed: busy ? null : onStart,
          icon: Icons.play_arrow_rounded,
        ),
      if (c.can('resolve')) AppButton(label: 'Mark resolved', onPressed: busy ? null : onResolve, icon: Icons.check_rounded),
      if (c.can('hold'))
        AppButton(label: 'Put on hold', onPressed: busy ? null : onHold, variant: AppButtonVariant.secondary, icon: Icons.pause_rounded),
      if (c.can('rate')) AppButton(label: 'Rate the fix', onPressed: busy ? null : onRate, icon: Icons.star_outline_rounded),
      if (c.can('reopen')) AppButton(label: 'It isn’t fixed', onPressed: busy ? null : onReopen, variant: AppButtonVariant.secondary),
      if (c.can('set_priority'))
        AppButton(label: 'Change priority', onPressed: busy ? null : onPriority, variant: AppButtonVariant.secondary, icon: Icons.flag_outlined),
      if (c.can('unassign')) AppButton(label: 'Take back', onPressed: busy ? null : onUnassign, variant: AppButtonVariant.ghost),
      if (c.can('reject')) AppButton(label: 'Decline', onPressed: busy ? null : onReject, variant: AppButtonVariant.ghost),
      if (c.can('close'))
        AppButton(
          label: c.status == ComplaintStatus.resolved ? 'Close it' : 'Withdraw',
          onPressed: busy ? null : onClose,
          variant: AppButtonVariant.ghost,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.history);
  final List<ComplaintHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final h in history.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(h.toStatus.label, tone: complaintTone(h.toStatus)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'by ${h.actorRole.label} · ${fmtDateTime(h.createdAt)}',
                        style: t.bodySmall?.copyWith(color: context.colors.mutedForeground),
                      ),
                    ),
                  ],
                ),
                if (h.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(h.note!, style: t.bodyMedium),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Comments extends StatelessWidget {
  const _Comments(this.comments);
  final List<ComplaintComment> comments;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    if (comments.isEmpty) return Text('No comments yet.', style: t.bodyMedium?.copyWith(color: c.mutedForeground));
    return Column(
      children: [
        for (final m in comments)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.authorName} · ${humanize(m.authorRole.name)}${m.internal ? ' · staff only' : ''} · ${relativeTime(m.createdAt)}',
                  style: t.bodySmall?.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: 4),
                Text(m.body, style: t.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}
