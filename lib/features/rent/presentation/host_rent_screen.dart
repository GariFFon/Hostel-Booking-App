import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../host/presentation/host_gate.dart';
import '../application/rent_providers.dart';
import '../domain/rent_models.dart';
import 'my_rent_section.dart';
import 'receipt_widgets.dart';

/// The owner's rent: what is billed, collected and owed this month, and every invoice, with a way to record money received.
class HostRentScreen extends ConsumerWidget {
  const HostRentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HostGate(
      title: 'Rent',
      child: DefaultTabController(
        length: HostRentTab.values.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Rent'),
            bottom: TabBar(tabs: [for (final tab in HostRentTab.values) Tab(text: tab.label)]),
          ),
          body: Column(
            children: [
              const _RollSummary(),
              Expanded(
                child: TabBarView(children: [for (final tab in HostRentTab.values) _InvoicesTab(tab: tab)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollSummary extends ConsumerWidget {
  const _RollSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final c = context.colors;
    final roll = ref.watch(rentRollProvider);
    return roll.when(
      loading: () => const SizedBox(height: 96),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(rentRollProvider)),
      ),
      data: (r) {
        final x = r.totals;
        Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(
                  value,
                  style: t.titleMedium?.copyWith(color: color).tabular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.month} · ${plural(r.activeTenants, 'tenant')}', style: t.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    stat('Billed', money(x.invoicedPaise)),
                    stat('Collected', money(x.collectedPaise)),
                    stat('Owed', money(x.outstandingPaise)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    stat('Overdue', money(x.overduePaise), color: x.overdueCount > 0 ? c.destructive : null),
                    stat('Online', money(x.collectedOnlinePaise)),
                    stat('Recorded', money(x.collectedOfflinePaise)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab({required this.tab});
  final HostRentTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = hostInvoicesProvider(tab);
    return PagedScroll<RentInvoice>(
      value: ref.watch(provider),
      onLoadMore: () => ref.read(provider.notifier).loadMore(),
      onRefresh: () async {
        ref.invalidate(provider);
        ref.invalidate(rentRollProvider);
        await ref.read(provider.future);
      },
      empty: EmptyState(
        icon: Icons.payments_outlined,
        title: tab == HostRentTab.overdue ? 'Nothing overdue' : 'No invoices here',
        message: tab == HostRentTab.overdue
            ? 'Every tenant is paid up or still within the grace period.'
            : 'Invoices appear here once a tenant has moved in.',
      ),
      itemBuilder: (context, i, _) => _InvoiceRow(
        invoice: i,
        onTap: () async {
          final changed = await showAppSheet<bool>(context, builder: (_) => _InvoiceSheet(id: i.id));
          if (changed == true) {
            ref.invalidate(hostInvoicesProvider);
            ref.invalidate(rentRollProvider);
          }
        },
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onTap});
  final RentInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final i = invoice;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(i.tenant.display, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                StatusChip(i.overdue.isOverdue ? '${i.overdue.days}d overdue' : i.status.label, tone: invoiceTone(i)),
              ],
            ),
            Text('${i.hostel.name} · bed ${i.tenancy.unitLabel}', style: t.bodySmall),
            const SizedBox(height: 6),
            Text('${fmtShort(i.start)} to ${fmtShort(i.end)} · due ${fmtLong(i.due)}', style: t.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(money(i.totalPaise), style: t.titleMedium?.tabular),
                if (i.status.isOpen && i.paidPaise > 0) Text('  ${money(i.balancePaise)} left', style: t.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One invoice: its lines and payments, and a way to record money received.
class _InvoiceSheet extends ConsumerStatefulWidget {
  const _InvoiceSheet({required this.id});
  final String id;

  @override
  ConsumerState<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends ConsumerState<_InvoiceSheet> {
  late Future<RentInvoice> _future = ref.read(rentRepositoryProvider).hostInvoice(widget.id);
  bool _changed = false;

  Future<void> _record(RentInvoice i) async {
    final r = await showAppSheet<({int amountPaise, String method, String reference})>(context, builder: (_) => _RecordSheet(invoice: i));
    if (r == null || !mounted) return;
    try {
      await ref.read(rentRepositoryProvider).recordPayment(i.id, amountPaise: r.amountPaise, method: r.method, reference: r.reference);
      _changed = true;
      if (mounted) {
        showToast(context, 'Payment recorded');
        setState(() {
          _future = ref.read(rentRepositoryProvider).hostInvoice(widget.id);
        });
      }
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _refund(RentPaymentItem p) async {
    final done = await showRefundSheet(context, p);
    if (done != true || !mounted) return;
    _changed = true;
    showToast(context, 'Refund started');
    setState(() {
      _future = ref.read(rentRepositoryProvider).hostInvoice(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: FutureBuilder<RentInvoice>(
        future: _future,
        builder: (context, snap) {
          final i = snap.data;
          return SheetFrame(
            title: i == null ? 'Invoice' : 'Invoice ${i.number}',
            footer: i != null && i.can('record_payment') ? AppButton(label: 'Record payment', onPressed: () => _record(i)) : null,
            child: i == null
                ? (snap.hasError
                      ? ErrorState(error: snap.error!, compact: true)
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator.adaptive()),
                        ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i.tenant.display} · ${i.hostel.name} · bed ${i.tenancy.unitLabel}', style: t.bodyMedium),
                      Text('${fmtLong(i.start)} to ${fmtLong(i.end)} · due ${fmtLong(i.due)}', style: t.bodySmall),
                      const SizedBox(height: 12),
                      if (i.openOrder != null) ...[
                        Text(
                          'The tenant is paying this online right now. Try again in a few minutes.',
                          style: t.bodySmall?.copyWith(color: context.colors.warning),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final l in i.lines) _line(context, l.description, l.amountPaise),
                      if (i.taxPaise > 0) _line(context, 'GST (${i.gstRateBps / 100}%)', i.taxPaise),
                      const Divider(),
                      _line(context, 'Total', i.totalPaise, bold: true),
                      _line(context, 'Paid', i.paidPaise),
                      _line(context, 'Balance', i.balancePaise, bold: true),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InvoicePdfButton(invoiceId: i.id, host: true),
                      ),
                      if (i.payments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Payments', style: t.titleSmall),
                        for (final p in i.payments)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${money(p.amountPaise)} · ${p.methodLabel} · ${fmtShort(p.received)} · ${p.receiptNo}${p.reversed ? ' (reversed)' : ''}',
                                  style: t.bodySmall?.copyWith(decoration: p.reversed ? TextDecoration.lineThrough : null),
                                ),
                                RefundNotes(p),
                                if (!p.reversed)
                                  Wrap(
                                    children: [
                                      ReceiptButton(payment: p, host: true),
                                      if (p.canRefund)
                                        TextButton.icon(
                                          onPressed: () => _refund(p),
                                          icon: const Icon(Icons.undo_rounded, size: 18),
                                          label: const Text('Refund'),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('To reverse a payment, add a charge, or cancel an invoice, use the website.', style: t.bodySmall),
                        ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, String label, int paise, {bool bold = false}) {
    final t = context.text;
    final style = bold ? t.titleSmall?.tabular : t.bodyMedium?.tabular;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? t.titleSmall : t.bodyMedium)),
          Text(money(paise), style: style),
        ],
      ),
    );
  }
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({required this.invoice});
  final RentInvoice invoice;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  late final _amount = TextEditingController(text: (widget.invoice.balancePaise / 100).toString().replaceAll(RegExp(r'\.0$'), ''));
  final _reference = TextEditingController();
  String _method = 'UPI';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_amount.text.trim());
    final paise = v == null ? 0 : (v * 100).round();
    if (paise < 100) return setState(() => _error = 'Enter at least ₹1');
    if (paise > widget.invoice.balancePaise) return setState(() => _error = 'That is more than the ${money(widget.invoice.balancePaise)} still owed');
    Navigator.of(context).pop((amountPaise: paise, method: _method, reference: _reference.text));
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Record payment',
      footer: AppButton(label: 'Record', onPressed: _submit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${money(widget.invoice.balancePaise)} is still owed. Enter what you actually received.', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Amount (₹)',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _error,
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          AppSegmented<String>(
            semanticLabel: 'Paid by',
            options: const [(value: 'UPI', label: 'UPI'), (value: 'CASH', label: 'Cash'), (value: 'BANK', label: 'Bank')],
            value: _method,
            onChanged: (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Reference', optional: true, helper: 'UTR, receipt number…', controller: _reference, maxLength: 100),
        ],
      ),
    );
  }
}
