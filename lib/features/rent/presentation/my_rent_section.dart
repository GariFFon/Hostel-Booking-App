import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../application/rent_providers.dart';
import '../domain/rent_models.dart';
import 'receipt_widgets.dart';
import 'rent_pay_sheet.dart';

Tone invoiceTone(RentInvoice i) => i.overdue.isOverdue
    ? Tone.danger
    : switch (i.status) {
        InvoiceStatus.paid => Tone.success,
        InvoiceStatus.due || InvoiceStatus.partiallyPaid => Tone.warning,
        _ => Tone.neutral,
      };

/// The tenant's rent on "My stay": what is owed, what was paid, and a way to pay. Hidden until they have been billed.
class MyRentSection extends ConsumerWidget {
  const MyRentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(myInvoicesProvider).value?.items ?? const <RentInvoice>[];
    if (invoices.isEmpty) return const SizedBox.shrink();
    final t = context.text;
    final owed = invoices.where((i) => i.status.isOpen).fold<int>(0, (n, i) => n + i.balancePaise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Rent')),
            if (owed > 0) Text('Total due ${money(owed)}', style: t.bodySmall?.tabular),
          ],
        ),
        for (final i in invoices) ...[_InvoiceCard(invoice: i), const SizedBox(height: 12)],
      ],
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.invoice});
  final RentInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final i = invoice;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${fmtShort(i.start)} to ${fmtShort(i.end)}', style: t.titleSmall)),
              StatusChip(i.overdue.isOverdue ? '${i.overdue.days}d overdue' : i.status.label, tone: invoiceTone(i)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${i.number} · due ${fmtLong(i.due)}', style: t.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(money(i.totalPaise), style: t.titleMedium?.tabular),
              if (i.status.isOpen && i.paidPaise > 0) Text('  ${money(i.balancePaise)} left', style: t.bodySmall),
            ],
          ),
          for (final l in i.lines.where((l) => l.type != 'RENT')) Text('${l.description}: ${money(l.amountPaise)}', style: t.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: InvoicePdfButton(invoiceId: i.id),
          ),
          if (i.payments.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final p in i.payments)
              Text(
                '${fmtShort(p.received)} · ${p.methodLabel} · ${p.receiptNo}${p.reversed ? ' (reversed)' : ''}: ${money(p.amountPaise)}',
                style: t.bodySmall?.copyWith(decoration: p.reversed ? TextDecoration.lineThrough : null),
              ),
            for (final p in i.payments.where((p) => !p.reversed)) ...[
              RefundNotes(p),
              Align(
                alignment: Alignment.centerLeft,
                child: ReceiptButton(payment: p),
              ),
            ],
          ],
          if (i.can('pay')) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Pay ${money(i.balancePaise)}',
              compact: true,
              expand: false,
              onPressed: () async {
                final paid = await showRentPaySheet(context, i);
                if (paid == true && context.mounted) showToast(context, 'Rent paid');
                ref.invalidate(myInvoicesProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}
