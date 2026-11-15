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
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../rent/presentation/receipt_widgets.dart';
import '../../rent/presentation/rent_pay_sheet.dart';
import '../application/tenancy_providers.dart';
import '../domain/tenancy_models.dart';
import 'settlement_editor.dart';

Tone settlementTone(SettlementStatus s) => switch (s) {
  SettlementStatus.completed => Tone.success,
  SettlementStatus.disputed => Tone.danger,
  SettlementStatus.proposed || SettlementStatus.agreed => Tone.info,
  _ => Tone.neutral,
};

/// Asks for the day the tenant will have moved out (never earlier than the stay's notice period) and an optional reason.
Future<({String date, String reason})?> showNoticeSheet(BuildContext context, {required int noticeDays, required bool owner}) =>
    showAppSheet<({String date, String reason})>(
      context,
      builder: (_) => _NoticeSheet(noticeDays: noticeDays, owner: owner),
    );

class _NoticeSheet extends StatefulWidget {
  const _NoticeSheet({required this.noticeDays, required this.owner});
  final int noticeDays;
  final bool owner;

  @override
  State<_NoticeSheet> createState() => _NoticeSheetState();
}

class _NoticeSheetState extends State<_NoticeSheet> {
  late final DateTime _earliest = today().add(Duration(days: widget.noticeDays));
  late DateTime _day = _earliest;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: _earliest, lastDate: today().add(const Duration(days: 365)));
    if (d != null) setState(() => _day = d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return SheetFrame(
      title: widget.owner ? 'Serve notice' : 'Give notice',
      footer: AppButton(
        label: widget.owner ? 'Serve notice' : 'Give notice',
        onPressed: () => Navigator.of(context).pop((date: toApiDate(_day), reason: _reason.text.trim())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.noticeDays > 0
                ? 'This stay needs ${widget.noticeDays} days\' notice. The earliest move-out is ${fmtLong(_earliest)}. Rent stops after the move-out day.'
                : 'Choose the move-out day. Rent stops after that day.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Move-out day: ${fmtLong(_day)}',
            excludeSemantics: true,
            child: InkWell(
              onTap: _pick,
              borderRadius: Radii.baseR,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: Radii.baseR,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Move out on ${fmtLong(_day)}', style: t.bodyLarge)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Reason',
            optional: true,
            controller: _reason,
            maxLength: 500,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}

/// The owner records that the tenant has left (today or an earlier day).
Future<({String? date, String note})?> showMoveOutSheet(BuildContext context, Tenancy t) =>
    showAppSheet<({String? date, String note})>(context, builder: (_) => _MoveOutSheet(t: t));

class _MoveOutSheet extends StatefulWidget {
  const _MoveOutSheet({required this.t});
  final Tenancy t;

  @override
  State<_MoveOutSheet> createState() => _MoveOutSheetState();
}

class _MoveOutSheetState extends State<_MoveOutSheet> {
  DateTime _day = today();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return SheetFrame(
      title: 'Record move-out',
      footer: AppButton(label: 'Record move-out', onPressed: () => Navigator.of(context).pop((date: toApiDate(_day), note: _note.text.trim()))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.t.tenantLabel} leaves bed ${widget.t.unit.label}. Billing stops, the bed becomes free and the deposit settlement starts. This cannot be undone.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _day, firstDate: widget.t.start, lastDate: today());
              if (d != null) setState(() => _day = d);
            },
            borderRadius: Radii.baseR,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: Radii.baseR,
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Moved out on ${fmtLong(_day)}', style: t.bodyLarge)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Note', optional: true, controller: _note, maxLength: 500, maxLines: 2),
        ],
      ),
    );
  }
}

/// What is deducted and what comes back.
class SettlementView extends StatelessWidget {
  const SettlementView({super.key, required this.s});
  final DepositSettlement s;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(s.status.label, tone: settlementTone(s.status)),
        const SizedBox(height: 10),
        _Line('Deposit held', money(s.depositPaise)),
        for (final d in s.deductions) _Line('− ${d.description} (${d.typeLabel})', money(d.amountPaise), muted: true),
        const Divider(),
        _Line('Comes back to the tenant', money(s.refundPaise), bold: true),
        if (s.note != null && s.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Owner\'s note: ${s.note}', style: t.bodyMedium),
          ),
        if (s.disputeNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('The tenant says: ${s.disputeNote}', style: t.bodyMedium?.copyWith(color: c.warning)),
          ),
        if (s.proofs.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: s.proofs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  s.proofs[i].url,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  semanticLabel: 'Evidence photo ${i + 1}',
                  errorBuilder: (_, _, _) => const SizedBox(width: 76, height: 76, child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        ],
        if (s.status == SettlementStatus.proposed && s.respondBy != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Respond by ${fmtDateTime(s.respondBy!)}. Silence counts as acceptance.', style: t.bodySmall),
          ),
        if (s.autoAgreed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Accepted automatically: no answer within 7 days.', style: t.bodySmall),
          ),
        if (s.status == SettlementStatus.completed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              s.refundPaise == 0
                  ? 'Nothing was due back.'
                  : s.payout.online
                  ? '${money(s.refundPaise)} was refunded to the original payment method.'
                  : '${money(s.refundPaise)} was returned${s.payout.method != null ? ' by ${humanize(s.payout.method!)}' : ''}${s.payout.reference != null ? ' (${s.payout.reference})' : ''}.',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.muted = false});
  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : null, color: muted ? context.colors.mutedForeground : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// The tenant's part of a stay: notice, paying the deposit online, and the deposit settlement.
class TenantLeavingSection extends ConsumerStatefulWidget {
  const TenantLeavingSection({super.key, required this.tenancy});
  final Tenancy tenancy;

  @override
  ConsumerState<TenantLeavingSection> createState() => _TenantLeavingSectionState();
}

class _TenantLeavingSectionState extends ConsumerState<TenantLeavingSection> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(myTenanciesProvider);
      ref.invalidate(mySettlementProvider(widget.tenancy.id));
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.tenancy;
    final repo = ref.read(tenancyRepositoryProvider);
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (x.notice != null && x.status == TenancyStatus.notice) ...[
          const SizedBox(height: 12),
          StatusChip('Moving out ${x.notice!.moveOut == null ? '' : fmtLong(x.notice!.moveOut!)}', tone: Tone.warning),
          Text(
            '${x.notice!.byTenant ? 'You gave notice.' : 'The owner gave notice.'}${x.notice!.reason != null ? ' ${x.notice!.reason}' : ''}',
            style: t.bodySmall,
          ),
        ],
        if (x.can('pay_deposit') || x.can('give_notice') || x.can('withdraw_notice')) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (x.can('pay_deposit'))
                AppButton(
                  label: 'Pay deposit online',
                  compact: true,
                  expand: false,
                  onPressed: () async {
                    final paid = await showDepositPaySheet(context, tenancyId: x.id, code: x.code, amountPaise: x.depositPaise);
                    ref.invalidate(myTenanciesProvider);
                    if (paid == true && context.mounted) showToast(context, 'Deposit paid');
                  },
                ),
              if (x.can('give_notice'))
                AppButton(
                  label: 'Give notice',
                  compact: true,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    final n = await showNoticeSheet(context, noticeDays: x.noticeDays, owner: false);
                    if (n == null || !mounted) return;
                    await _run(() => repo.giveNotice(x.id, moveOutDate: n.date, reason: n.reason), 'Notice given. The owner has been told.');
                  },
                ),
              if (x.can('withdraw_notice'))
                AppButton(
                  label: 'Withdraw notice',
                  compact: true,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _run(() => repo.withdrawNotice(x.id), 'Notice withdrawn. Your stay continues.'),
                ),
            ],
          ),
        ],
        if (x.deposit.isReceived)
          Align(
            alignment: Alignment.centerLeft,
            child: PdfLinkButton(label: 'Deposit receipt (PDF)', fetch: (ref) => ref.read(tenancyRepositoryProvider).depositReceiptLink(x.id)),
          ),
        if (x.settlement != null) ...[const SizedBox(height: 16), const Divider(), _Settlement(tenancyId: x.id)],
      ],
    );
  }
}

class _Settlement extends ConsumerWidget {
  const _Settlement({required this.tenancyId});
  final String tenancyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySettlementProvider(tenancyId));
    final repo = ref.read(tenancyRepositoryProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(mySettlementProvider(tenancyId))),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Your deposit'),
          SettlementView(s: s),
          if (s.can('accept')) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Accept',
                    compact: true,
                    onPressed: () async {
                      try {
                        await repo.acceptSettlement(tenancyId);
                        ref.invalidate(mySettlementProvider(tenancyId));
                        ref.invalidate(myTenanciesProvider);
                        if (context.mounted) showToast(context, 'Accepted');
                      } catch (e) {
                        if (context.mounted) showErrorToast(context, e);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Dispute',
                    compact: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: () async {
                      final note = await _askNote(
                        context,
                        title: 'Dispute this settlement',
                        message: 'Tell the owner what is wrong. They can change it and send it again, or ask support to decide.',
                        label: 'What is wrong?',
                        confirm: 'Send dispute',
                      );
                      if (note == null || !context.mounted) return;
                      try {
                        await repo.disputeSettlement(tenancyId, note);
                        ref.invalidate(mySettlementProvider(tenancyId));
                        ref.invalidate(myTenanciesProvider);
                        if (context.mounted) showToast(context, 'The owner has been told');
                      } catch (e) {
                        if (context.mounted) showErrorToast(context, e);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _askNote(BuildContext context, {required String title, required String message, required String label, required String confirm}) =>
    showAppSheet<String>(
      context,
      builder: (_) => _NoteSheet(title: title, message: message, label: label, confirm: confirm),
    );

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.title, required this.message, required this.label, required this.confirm});
  final String title;
  final String message;
  final String label;
  final String confirm;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      footer: AppButton(
        label: widget.confirm,
        onPressed: () {
          if (_c.text.trim().length < 5) return setState(() => _error = 'Add a few words (at least 5 characters)');
          Navigator.of(context).pop(_c.text.trim());
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: context.text.bodyMedium),
          const SizedBox(height: 12),
          AppTextField(
            label: widget.label,
            controller: _c,
            maxLength: 1000,
            maxLines: 3,
            errorText: _error,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}

/// The owner's settlement sheet: read it, send the pre-filled draft, take it back, or record how a cash deposit was refunded.
/// Custom deductions and evidence photos are added on the website.
Future<void> showHostSettlementSheet(BuildContext context, Tenancy t) => showAppSheet<void>(context, builder: (_) => _HostSettlementSheet(t: t));

class _HostSettlementSheet extends ConsumerStatefulWidget {
  const _HostSettlementSheet({required this.t});
  final Tenancy t;

  @override
  ConsumerState<_HostSettlementSheet> createState() => _HostSettlementSheetState();
}

class _HostSettlementSheetState extends ConsumerState<_HostSettlementSheet> {
  bool _busy = false;
  String _method = 'UPI';
  final _reference = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Object?> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(hostSettlementProvider(widget.t.id));
      ref.invalidate(hostTenanciesProvider);
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hostSettlementProvider(widget.t.id));
    final repo = ref.read(tenancyRepositoryProvider);
    return SheetFrame(
      title: 'Deposit settlement',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(hostSettlementProvider(widget.t.id))),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.t.tenantLabel}: what is deducted from the deposit, and what goes back.', style: context.text.bodyMedium),
            const SizedBox(height: 12),
            if (!s.can('edit')) SettlementView(s: s),
            if (s.can('edit')) ...[
              const SizedBox(height: 4),
              SettlementEditor(
                key: ValueKey(s.id),
                settlement: s,
                tenancyId: widget.t.id,
                onChanged: () {
                  ref.invalidate(hostSettlementProvider(widget.t.id));
                  ref.invalidate(hostTenanciesProvider);
                },
              ),
            ],
            if (s.can('retract')) ...[
              const SizedBox(height: 12),
              AppButton(
                label: 'Take it back to edit',
                variant: AppButtonVariant.secondary,
                loading: _busy,
                onPressed: () => _run(() => repo.retractSettlement(widget.t.id), 'Taken back'),
              ),
            ],
            if (s.can('record_payout')) ...[
              const SizedBox(height: 16),
              Text('Record the refund you paid', style: context.text.titleSmall),
              const SizedBox(height: 4),
              Text('The deposit was not paid online, so you pay ${money(s.refundPaise)} back yourself. Tell us how.', style: context.text.bodySmall),
              const SizedBox(height: 8),
              AppSegmented<String>(
                semanticLabel: 'Paid by',
                options: const [(value: 'UPI', label: 'UPI'), (value: 'CASH', label: 'Cash'), (value: 'BANK', label: 'Bank')],
                value: _method,
                onChanged: (v) => setState(() => _method = v),
              ),
              const SizedBox(height: 8),
              AppTextField(label: 'Reference', optional: true, controller: _reference, maxLength: 100),
              const SizedBox(height: 8),
              AppButton(
                label: 'Record refund',
                loading: _busy,
                onPressed: () => _run(
                  () => repo.recordPayout(widget.t.id, method: _method, reference: _reference.text),
                  'Refund recorded. The deposit is settled.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
