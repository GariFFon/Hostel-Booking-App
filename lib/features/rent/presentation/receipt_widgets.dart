import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/sheet.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/rent_models.dart';

/// A button that asks the server for a five-minute signed link to a PDF and opens it in the browser / PDF viewer.
class PdfLinkButton extends ConsumerStatefulWidget {
  const PdfLinkButton({super.key, required this.label, required this.fetch});
  final String label;

  /// Asks the server for the link (so each kind of document says where to ask).
  final Future<String> Function(WidgetRef ref) fetch;

  @override
  ConsumerState<PdfLinkButton> createState() => _PdfLinkButtonState();
}

class _PdfLinkButtonState extends ConsumerState<PdfLinkButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await widget.fetch(ref);
      final opened = await ref.read(urlOpenerProvider)(url);
      if (!opened && mounted) showToast(context, 'Could not open the document. Try again.', error: true);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _open,
    icon: _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
    label: Text(widget.label),
  );
}

/// "Receipt (PDF)" for one payment.
class ReceiptButton extends StatelessWidget {
  const ReceiptButton({super.key, required this.payment, this.host = false});
  final RentPaymentItem payment;
  final bool host;

  @override
  Widget build(BuildContext context) => PdfLinkButton(
    label: 'Receipt (PDF)',
    fetch: (ref) => ref.read(rentRepositoryProvider).receiptLink(payment.id, host: host),
  );
}

/// "Invoice (PDF)" for a rent invoice.
class InvoicePdfButton extends StatelessWidget {
  const InvoicePdfButton({super.key, required this.invoiceId, this.host = false});
  final String invoiceId;
  final bool host;

  @override
  Widget build(BuildContext context) => PdfLinkButton(
    label: 'Invoice (PDF)',
    fetch: (ref) => ref.read(rentRepositoryProvider).invoicePdfLink(invoiceId, host: host),
  );
}

/// What has been returned on a payment, in words.
class RefundNotes extends StatelessWidget {
  const RefundNotes(this.payment, {super.key});
  final RentPaymentItem payment;

  @override
  Widget build(BuildContext context) {
    if (payment.refunds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in payment.refunds)
          Text('${r.label} ${money(r.amountPaise)}: ${r.reason}', style: context.text.bodySmall?.copyWith(color: context.colors.mutedForeground)),
      ],
    );
  }
}

/// The owner returns part or all of an online payment. Resolves to true once the refund was started.
Future<bool?> showRefundSheet(BuildContext context, RentPaymentItem payment) =>
    showAppSheet<bool>(context, builder: (_) => _RefundSheet(payment: payment));

class _RefundSheet extends ConsumerStatefulWidget {
  const _RefundSheet({required this.payment});
  final RentPaymentItem payment;

  @override
  ConsumerState<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends ConsumerState<_RefundSheet> {
  late final _amount = TextEditingController(text: (widget.payment.refundablePaise / 100).toString().replaceFirst(RegExp(r'\.0$'), ''));
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = double.tryParse(_amount.text.trim());
    final paise = v == null ? 0 : (v * 100).round();
    final local = <String, String>{
      if (paise < 1) 'amount': 'Enter an amount',
      if (paise > widget.payment.refundablePaise) 'amount': 'At most ${money(widget.payment.refundablePaise)} can be refunded',
      if (_reason.text.trim().length < 3) 'reason': 'Give a reason (the tenant is told)',
    };
    if (local.isNotEmpty) return setState(() => _fields = local);
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
    });
    try {
      await ref.read(rentRepositoryProvider).refund(widget.payment.id, amountPaise: paise, reason: _reason.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.userMessage;
          _fields = {'amount': ?e.fieldErrors['amountPaise'], 'reason': ?e.fieldErrors['reason']};
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return SheetFrame(
      title: 'Refund this payment',
      footer: AppButton(label: 'Refund', onPressed: _submit, loading: _busy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.receiptNo} · paid ${money(p.amountPaise)} online. Up to ${money(p.refundablePaise)} goes back to the tenant\'s original payment method, and the invoice owes it again.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
          AppTextField(
            label: 'Amount (₹)',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _fields['amount'],
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Reason',
            controller: _reason,
            maxLength: 300,
            maxLines: 3,
            errorText: _fields['reason'],
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
