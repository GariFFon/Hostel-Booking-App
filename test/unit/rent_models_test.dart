import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/router/routes.dart';
import 'package:hostel_booking_app/features/rent/domain/rent_models.dart';

import '../support/rent_support.dart';

void main() {
  test('an invoice parses with its lines, payments and what the viewer may do', () {
    final i = RentInvoice.fromJson(
      invoiceJson(
        status: 'PARTIALLY_PAID',
        paid: 250000,
        payments: [paymentJson()],
        extraLines: [
          {'id': 'l2', 'type': 'ELECTRICITY', 'description': 'Electricity', 'amountPaise': 45000},
        ],
        actions: const ['pay'],
      ),
    );
    expect(i.status, InvoiceStatus.partiallyPaid);
    expect(i.status.isOpen, isTrue);
    expect(i.balancePaise, 500000);
    expect(i.lines.map((l) => l.type), ['RENT', 'ELECTRICITY']);
    expect(i.payments.single.receiptNo, 'RCPT-2702-XYZ789');
    expect(i.payments.single.methodLabel, 'Cash');
    expect(i.can('pay'), isTrue);
    expect(i.can('record_payment'), isFalse);
    expect(i.start, DateTime(2027, 2, 1));
    expect(i.due, DateTime(2027, 2, 5));
    expect(i.tenant.display, 'Asha Rao');
  });

  test('cancelled and unknown statuses are handled without crashing', () {
    expect(RentInvoice.fromJson(invoiceJson(status: 'VOID', actions: const [])).status, InvoiceStatus.voided);
    expect(InvoiceStatus.voided.isOpen, isFalse);
    expect(RentInvoice.fromJson(invoiceJson(status: 'SOMETHING_NEW')).status, InvoiceStatus.unknown);
    expect(RentInvoice.fromJson(invoiceJson(status: 'PAID', paid: 750000)).status.isOpen, isFalse);
  });

  test('overdue and open orders come through', () {
    final i = RentInvoice.fromJson(invoiceJson(overdue: true, overdueDays: 4, openOrder: {'id': 'o1', 'status': 'PENDING', 'amountPaise': 750000}));
    expect(i.overdue.isOverdue, isTrue);
    expect(i.overdue.days, 4);
    expect(i.openOrder?.status, 'PENDING');
  });

  test('an online payment order and the gateway outcomes parse', () {
    final open = RentOrder.fromJson(orderJson());
    expect(open.status, RentOrderStatus.created);
    expect(open.status.isOpen, isTrue);
    expect(open.checkout?.instruments, contains('DEMO_SUCCESS'));
    final done = RentOrder.fromJson(orderJson(status: 'CAPTURED'));
    expect(done.status.isOpen, isFalse);
    expect(done.checkout, isNull);
    expect(RentOrder.fromJson(orderJson(status: 'FAILED', failure: 'Declined')).failureReason, 'Declined');
    expect(RentOrder.fromJson(orderJson(status: 'WEIRD')).status, RentOrderStatus.unknown);
  });

  test('the rent roll parses', () {
    final r = RentRoll.fromJson(rollJson(overdueCount: 2));
    expect(r.month, '2027-02');
    expect(r.activeTenants, 3);
    expect(r.totals.collectedOnlinePaise + r.totals.collectedOfflinePaise, r.totals.collectedPaise);
    expect(r.totals.overduePaise, 1500000);
  });

  test('the rent screens need a signed-in user', () {
    expect(Routes.needsSignIn(Routes.hostRent), isTrue);
  });
}
