import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../complaints/presentation/photo_widgets.dart';
import '../domain/tenancy_models.dart';

const _types = [('DAMAGE', 'Damage'), ('CLEANING', 'Cleaning'), ('UTILITIES', 'Utilities'), ('OTHER', 'Other'), ('UNPAID_RENT', 'Unpaid rent')];
const maxSettlementPhotos = 10;

class _Row {
  _Row({required this.type, String description = '', String amount = '', this.invoiceId})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);
  String type;
  final TextEditingController description;
  final TextEditingController amount;
  String? invoiceId;
  final key = UniqueKey();

  int get paise {
    final v = double.tryParse(amount.text.trim());
    return v == null ? 0 : (v * 100).round();
  }

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

/// The owner's working copy of a deposit settlement: itemise what is kept (unpaid rent is pre-filled), add evidence photos and a note,
/// save the draft, or send it to the tenant. Nothing here decides permissions: the server re-checks every number.
class SettlementEditor extends ConsumerStatefulWidget {
  const SettlementEditor({super.key, required this.settlement, required this.tenancyId, required this.onChanged});
  final DepositSettlement settlement;
  final String tenancyId;

  /// Called after anything was saved or sent, so the screen behind can reload.
  final VoidCallback onChanged;

  @override
  ConsumerState<SettlementEditor> createState() => _SettlementEditorState();
}

class _SettlementEditorState extends ConsumerState<SettlementEditor> {
  late final List<_Row> _rows = [
    for (final d in widget.settlement.deductions)
      _Row(
        type: d.type,
        description: d.description,
        amount: (d.amountPaise / 100).toString().replaceFirst(RegExp(r'\.0$'), ''),
        invoiceId: d.invoiceId,
      ),
  ];
  late final _note = TextEditingController(text: widget.settlement.note ?? '');
  late List<SettlementProof> _proofs = widget.settlement.proofs;
  bool _busy = false;
  bool _photoBusy = false;
  String? _error;

  DepositSettlement get s => widget.settlement;
  int get _total => _rows.fold(0, (n, r) => n + r.paise);
  bool get _over => _total > s.depositPaise;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  String? _problem() {
    for (final r in _rows) {
      if (r.description.text.trim().length < 3) return 'Say what each deduction is for';
      if (r.paise <= 0) return 'Enter an amount for each deduction';
      if (r.type == 'UNPAID_RENT' && r.invoiceId == null) return 'Pick the invoice for each unpaid rent deduction';
    }
    if (_over) return 'Deductions can be at most the deposit held (${money(s.depositPaise)})';
    return null;
  }

  List<Map<String, Object?>> get _lines => [
    for (final r in _rows)
      {
        'type': r.type,
        'description': r.description.text.trim(),
        'amountPaise': r.paise,
        if (r.type == 'UNPAID_RENT' && r.invoiceId != null) 'invoiceId': r.invoiceId,
      },
  ];

  Future<void> _run(Future<void> Function() action, String done) async {
    final p = _problem();
    if (p != null) return setState(() => _error = p);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
      if (mounted) showToast(context, done);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(tenancyRepositoryProvider);
    await repo.saveSettlement(widget.tenancyId, deductions: _lines, note: _note.text);
  }

  Future<void> _addPhotos() async {
    final picked = await choosePhotos(context, ref, max: maxSettlementPhotos - _proofs.length);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photoBusy = true);
    final repo = ref.read(tenancyRepositoryProvider);
    String? firstError;
    var failed = 0;
    for (final p in picked) {
      try {
        _proofs = (await repo.addSettlementProof(widget.tenancyId, p)).proofs;
      } catch (e) {
        failed++;
        firstError ??= errorText(e);
      }
    }
    if (!mounted) return;
    setState(() => _photoBusy = false);
    widget.onChanged();
    if (failed > 0) {
      showToast(
        context,
        failed == picked.length ? (firstError ?? 'The photos could not be uploaded.') : '$failed of ${picked.length} photos could not be uploaded.',
        error: true,
      );
    }
  }

  Future<void> _removePhoto(SettlementProof p) async {
    try {
      final updated = await ref.read(tenancyRepositoryProvider).removeSettlementProof(widget.tenancyId, p.id);
      if (mounted) setState(() => _proofs = updated.proofs);
      widget.onChanged();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.status == SettlementStatus.disputed && s.disputeNote != null) ...[
          Text('The tenant says: ${s.disputeNote}', style: t.bodyMedium?.copyWith(color: c.warning)),
          const SizedBox(height: 4),
          Text('Change what is needed and send it again.', style: t.bodySmall),
          const SizedBox(height: 12),
        ],
        Text('Deposit held ${money(s.depositPaise)}', style: t.titleSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++)
          _RowEditor(
            key: _rows[i].key,
            index: i,
            row: _rows[i],
            invoices: s.openInvoices,
            onChanged: () => setState(() => _error = null),
            onRemove: () => setState(() => _rows.removeAt(i).dispose()),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _rows.add(_Row(type: 'DAMAGE'))),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add a deduction'),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _over ? c.tint(c.destructive) : c.muted, borderRadius: Radii.baseR),
            child: Text(
              _over
                  ? 'Deductions ${money(_total)} are more than the deposit'
                  : 'Deductions ${money(_total)} · back to the tenant ${money(s.depositPaise - _total)}',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: _over ? c.destructive : null),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Note to the tenant',
          optional: true,
          controller: _note,
          maxLength: 1000,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        const SectionTitle('Evidence photos'),
        if (_proofs.isNotEmpty)
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _proofs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _proofs[i].url,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      semanticLabel: 'Evidence photo ${i + 1}',
                      errorBuilder: (_, _, _) => const SizedBox(width: 84, height: 84, child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Remove evidence photo ${i + 1}',
                      child: InkWell(
                        onTap: () => _removePhoto(_proofs[i]),
                        child: Container(
                          decoration: BoxDecoration(color: c.foreground.withValues(alpha: 0.7), shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 14, color: c.background),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_proofs.length < maxSettlementPhotos)
          TextButton.icon(
            onPressed: _photoBusy ? null : _addPhotos,
            icon: _photoBusy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(_photoBusy ? 'Uploading…' : (_proofs.isEmpty ? 'Add photos (optional)' : 'Add more')),
          ),
        if (_proofs.isEmpty) Text('Photos of damage make a dispute much less likely.', style: t.bodySmall),
        if (_error != null) ...[const SizedBox(height: 12), FormErrorBanner(_error!)],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(label: 'Save draft', variant: AppButtonVariant.secondary, loading: _busy, onPressed: () => _run(_save, 'Saved')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Send to the tenant',
                loading: _busy,
                onPressed: () => _run(() async {
                  await _save();
                  await ref.read(tenancyRepositoryProvider).proposeSettlement(widget.tenancyId);
                }, 'Sent to the tenant'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RowEditor extends StatefulWidget {
  const _RowEditor({super.key, required this.index, required this.row, required this.invoices, required this.onChanged, required this.onRemove});
  final int index;
  final _Row row;
  final List<OpenInvoiceRef> invoices;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final n = widget.index + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: Radii.baseR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: r.type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Deduction $n'),
                  items: [for (final t in _types) DropdownMenuItem(value: t.$1, child: Text(t.$2))],
                  onChanged: (v) => setState(() {
                    r.type = v ?? r.type;
                    if (r.type != 'UNPAID_RENT') r.invoiceId = null;
                    widget.onChanged();
                  }),
                ),
              ),
              IconButton(tooltip: 'Remove deduction $n', onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(label: 'What it is for', controller: r.description, maxLength: 200, onChanged: (_) => widget.onChanged()),
          const SizedBox(height: 4),
          AppTextField(
            label: 'Amount (₹)',
            controller: r.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => widget.onChanged(),
          ),
          if (r.type == 'UNPAID_RENT') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: widget.invoices.any((i) => i.id == r.invoiceId) ? r.invoiceId : null,
              isExpanded: true,
              hint: const Text('Which invoice is this rent from?'),
              decoration: const InputDecoration(labelText: 'Invoice'),
              items: [
                for (final i in widget.invoices)
                  DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.number} · ${money(i.balancePaise)} owed', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                r.invoiceId = v;
                final inv = widget.invoices.where((i) => i.id == v).firstOrNull;
                if (inv != null && r.amount.text.trim().isEmpty) {
                  r.amount.text = (inv.balancePaise / 100).toString().replaceFirst(RegExp(r'\.0$'), '');
                }
                if (inv != null && r.description.text.trim().isEmpty) r.description.text = 'Unpaid rent, invoice ${inv.number}';
                widget.onChanged();
              }),
            ),
          ],
        ],
      ),
    );
  }
}
