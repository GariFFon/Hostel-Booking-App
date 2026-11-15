import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../application/rent_providers.dart';
import '../domain/rent_models.dart';

/// Pays an invoice's balance with the demo gateway. Like a real gateway the "bank" reports back asynchronously, and the invoice
/// only becomes PAID when the server says so: this sheet never decides that a payment succeeded. Resolves to true once paid.
Future<bool?> showRentPaySheet(BuildContext context, RentInvoice invoice) =>
    showAppSheet<bool>(context, builder: (_) => RentPaySheet(invoice: invoice));

/// The same sheet for the security deposit of a stay.
Future<bool?> showDepositPaySheet(BuildContext context, {required String tenancyId, required String code, required int amountPaise}) =>
    showAppSheet<bool>(context, builder: (_) => RentPaySheet(deposit: (tenancyId: tenancyId, code: code, amountPaise: amountPaise)));

enum _Phase { choose, processing, confirmed, failed, waiting }

const _outcomes = {
  'DEMO_SUCCESS': ('Pay successfully', 'The bank approves right away.'),
  'DEMO_PENDING': ('Takes a moment', 'Like UPI: confirmation arrives a few seconds later.'),
  'DEMO_FAIL': ('Payment fails', 'See what happens when the bank declines.'),
  'DEMO_TIMEOUT': ('Never completes', 'Nothing comes back from the bank.'),
};
const _defaultInstruments = ['DEMO_SUCCESS', 'DEMO_PENDING', 'DEMO_FAIL', 'DEMO_TIMEOUT'];

class RentPaySheet extends ConsumerStatefulWidget {
  const RentPaySheet({super.key, this.invoice, this.deposit}) : assert(invoice != null || deposit != null);

  /// Pays this invoice's balance, or...
  final RentInvoice? invoice;

  /// ...the security deposit of this stay.
  final ({String tenancyId, String code, int amountPaise})? deposit;

  @override
  ConsumerState<RentPaySheet> createState() => _RentPaySheetState();
}

class _RentPaySheetState extends ConsumerState<RentPaySheet> {
  _Phase _phase = _Phase.choose;
  RentOrder? _order;
  bool _starting = true;
  String? _error;
  String _instrument = 'DEMO_SUCCESS';
  String _method = 'UPI';

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Starts (or resumes) the order. After a failure a fresh one is needed: a failed order is final.
  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final repo = ref.read(rentRepositoryProvider);
      final order = widget.invoice != null ? await repo.startPayment(widget.invoice!.id) : await repo.startDepositPayment(widget.deposit!.tenancyId);
      if (mounted) setState(() => _order = order);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _pay() async {
    final order = _order;
    if (order == null) return;
    setState(() {
      _phase = _Phase.processing;
      _error = null;
    });
    final repo = ref.read(rentRepositoryProvider);
    try {
      await repo.demoCheckout(order.id, instrument: _instrument, method: _method);
      // Confirmation arrives by webhook: poll the order until the server says so (bounded: a timeout is a normal outcome).
      for (var i = 0; i < 36; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        final s = await repo.order(order.id);
        if (s.status == RentOrderStatus.captured) {
          ref.invalidate(myInvoicesProvider);
          ref.invalidate(myTenanciesProvider);
          if (mounted) setState(() => _phase = _Phase.confirmed);
          return;
        }
        if (s.status == RentOrderStatus.failed) {
          if (mounted) {
            setState(() {
              _error = s.failureReason ?? 'The bank declined this payment.';
              _phase = _Phase.failed;
              _order = null;
            });
            await _start();
          }
          return;
        }
      }
      if (mounted) setState(() => _phase = _Phase.waiting);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _phase = _Phase.failed;
        _order = null;
      });
      await _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final inv = widget.invoice;
    final amount = inv?.balancePaise ?? widget.deposit!.amountPaise;
    final ref0 = inv?.number ?? widget.deposit!.code;
    final isDeposit = inv == null;
    final instruments = (_order?.checkout?.instruments.isNotEmpty ?? false) ? _order!.checkout!.instruments : _defaultInstruments;

    Widget body;
    switch (_phase) {
      case _Phase.confirmed:
        body = Column(
          children: [
            Icon(Icons.check_circle_rounded, size: 56, color: c.success),
            const SizedBox(height: 12),
            Text(isDeposit ? 'Deposit paid' : 'Rent paid', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              isDeposit ? 'Your deposit for stay $ref0 is held safely until you move out.' : 'We have emailed your receipt for $ref0.',
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      case _Phase.processing:
        body = Column(
          children: [
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator.adaptive()),
            Text('Confirming with the bank…', style: t.titleMedium),
            const SizedBox(height: 4),
            Text("Please don't close this window.", style: t.bodySmall),
          ],
        );
      case _Phase.waiting:
        body = Column(
          children: [
            Icon(Icons.schedule_rounded, size: 48, color: c.warning),
            const SizedBox(height: 12),
            Text('Still waiting for the bank', style: t.titleMedium),
            const SizedBox(height: 4),
            Text("You haven't been charged twice. Your invoice updates when the payment arrives.", style: t.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: 'Close', onPressed: () => Navigator.of(context).pop(false), variant: AppButtonVariant.secondary),
          ],
        );
      case _Phase.choose || _Phase.failed:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.muted, borderRadius: Radii.baseR),
              child: Row(
                children: [
                  Expanded(child: Text('Amount to pay', style: t.bodyMedium)),
                  Text(money(amount), style: t.titleLarge?.tabular),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Demo payment: no real money moves. Pick how the "bank" should respond so you can see every outcome.', style: t.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_phase == _Phase.failed ? "Payment didn't go through. $_error" : _error!, style: t.bodyMedium?.copyWith(color: c.destructive)),
            ],
            const SizedBox(height: 16),
            Text('Pay with', style: t.titleSmall),
            const SizedBox(height: 8),
            AppSegmented<String>(
              semanticLabel: 'Pay with',
              options: const [(value: 'UPI', label: 'UPI'), (value: 'CARD', label: 'Card'), (value: 'NETBANKING', label: 'Net banking')],
              value: _method,
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: 16),
            Text('Simulate', style: t.titleSmall),
            RadioGroup<String>(
              groupValue: _instrument,
              onChanged: (v) => setState(() => _instrument = v ?? _instrument),
              child: Column(
                children: [
                  for (final i in instruments)
                    RadioListTile<String>(
                      value: i,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_outcomes[i]?.$1 ?? i),
                      subtitle: Text(_outcomes[i]?.$2 ?? ''),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppButton(label: 'Pay ${money(amount)}', loading: _starting, onPressed: _order == null ? null : _pay),
          ],
        );
    }

    return PopScope(
      canPop: _phase != _Phase.processing,
      child: SheetFrame(title: _phase == _Phase.confirmed ? 'Payment received' : (isDeposit ? 'Pay the security deposit' : 'Pay $ref0'), child: body),
    );
  }
}
