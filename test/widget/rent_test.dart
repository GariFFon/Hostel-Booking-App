import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/shared/widgets/app_button.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/rent/domain/rent_models.dart';
import 'package:hostel_booking_app/features/rent/presentation/host_rent_screen.dart';
import 'package:hostel_booking_app/features/rent/presentation/my_rent_section.dart';
import 'package:hostel_booking_app/features/rent/presentation/rent_pay_sheet.dart';

import '../support/rent_support.dart';
import '../support/support.dart';

const owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Olive Owner', emailVerified: true, roles: [UserRole.guest, UserRole.owner]);

List<Override> over(FakeRentRepository repo, {AppUser user = guestUser}) => [
  sessionProvider.overrideWith(() => FakeSession(user)),
  rentRepositoryProvider.overrideWithValue(repo),
];

RentInvoice invoice({String status = 'DUE', int paid = 0, List<String> actions = const ['pay'], bool overdue = false, int days = 0}) =>
    RentInvoice.fromJson(
      invoiceJson(
        status: status,
        paid: paid,
        actions: actions,
        overdue: overdue,
        overdueDays: days,
        payments: paid > 0 ? [paymentJson(amount: paid)] : const [],
      ),
    );

void main() {
  setUpAll(initLocale);

  group('the tenant\'s rent', () {
    testWidgets('lists invoices with what is owed, receipts, and a Pay button', (t) async {
      final repo = FakeRentRepository()
        ..mine = [invoice(status: 'PARTIALLY_PAID', paid: 250000), invoice(status: 'PAID', paid: 750000, actions: const [])];
      await pumpScreen(
        t,
        const Scaffold(body: SingleChildScrollView(child: MyRentSection())),
        overrides: over(repo),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      expect(find.text('Rent'), findsOneWidget);
      expect(find.textContaining('Total due ₹5,000'), findsOneWidget); // only the open invoice counts
      expect(find.text('Part paid'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.textContaining('RCPT-2702-XYZ789'), findsWidgets);
      expect(find.text('Pay ₹5,000'), findsOneWidget);
    });

    testWidgets('an overdue invoice says so', (t) async {
      final repo = FakeRentRepository()..mine = [invoice(overdue: true, days: 6)];
      await pumpScreen(
        t,
        const Scaffold(body: SingleChildScrollView(child: MyRentSection())),
        overrides: over(repo),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      expect(find.text('6d overdue'), findsOneWidget);
    });

    testWidgets('shows nothing until the tenant has been billed', (t) async {
      await pumpScreen(t, const Scaffold(body: MyRentSection()), overrides: over(FakeRentRepository()));
      await t.pumpAndSettle();
      expect(find.text('Rent'), findsNothing);
    });
  });

  group('receipts and refunds', () {
    final opened = <String>[];
    List<Override> withOpener(FakeRentRepository repo, {AppUser user = guestUser}) => [
      ...over(repo, user: user),
      urlOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
    ];
    RentInvoice online({bool canRefund = false, int refunded = 0, List<Map<String, dynamic>> refunds = const []}) => RentInvoice.fromJson(
      invoiceJson(
        status: refunded == 0 ? 'PAID' : 'PARTIALLY_PAID',
        paid: 750000 - refunded,
        actions: const [],
        payments: [paymentJson(amount: 750000, method: 'ONLINE', canRefund: canRefund, refunded: refunded, refunds: refunds)],
      ),
    );

    setUp(opened.clear);

    testWidgets('the tenant opens the PDF receipt through a signed link', (t) async {
      final repo = FakeRentRepository()..mine = [online()];
      await pumpScreen(
        t,
        const Scaffold(body: SingleChildScrollView(child: MyRentSection())),
        overrides: withOpener(repo),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Receipt (PDF)'));
      await t.pumpAndSettle();
      expect(repo.calls, contains('receipt'));
      expect(repo.lastReceiptFor, 'p1');
      expect(repo.lastReceiptAsHost, false);
      expect(opened, [repo.receiptUrl]);
    });

    testWidgets('the tenant opens an invoice as a PDF', (t) async {
      final repo = FakeRentRepository()..mine = [online()];
      await pumpScreen(
        t,
        const Scaffold(body: SingleChildScrollView(child: MyRentSection())),
        overrides: withOpener(repo),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Invoice (PDF)'));
      await t.pumpAndSettle();
      expect(repo.lastInvoicePdfFor, 'i1');
      expect(repo.lastInvoicePdfAsHost, false);
      expect(opened, [repo.invoicePdfUrl]);
    });

    testWidgets('the owner opens an invoice as a PDF from the invoice sheet', (t) async {
      final host = FakeRentRepository()..paid = [online()];
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: withOpener(host, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Paid'));
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Invoice (PDF)'));
      await t.pumpAndSettle();
      expect(host.lastInvoicePdfAsHost, true);
    });

    testWidgets('a reversed payment has no receipt, and a refund is shown in words', (t) async {
      final repo = FakeRentRepository()
        ..mine = [
          RentInvoice.fromJson(invoiceJson(payments: [paymentJson(reversed: true)])),
          online(
            refunded: 250000,
            refunds: [
              {'id': 'r1', 'amountPaise': 250000, 'status': 'PROCESSED', 'reason': 'Paid twice', 'byRole': 'OWNER'},
            ],
          ),
        ];
      await pumpScreen(
        t,
        const Scaffold(body: SingleChildScrollView(child: MyRentSection())),
        overrides: withOpener(repo),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      expect(find.text('Receipt (PDF)'), findsOneWidget); // only the live payment
      expect(find.textContaining('Refunded ₹2,500: Paid twice'), findsOneWidget);
    });

    testWidgets('the owner sees Refund only on an online payment that can still be refunded, and Receipt on any live one', (t) async {
      final repo = FakeRentRepository()
        ..paid = [
          online(canRefund: true),
          RentInvoice.fromJson(invoiceJson(id: 'i2', status: 'PAID', paid: 250000, actions: const [], payments: [paymentJson()])),
        ];
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: withOpener(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Paid'));
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao').first);
      await t.pumpAndSettle();
      expect(find.text('Refund'), findsOneWidget);
      expect(find.text('Receipt (PDF)'), findsOneWidget);
      await t.tap(find.text('Receipt (PDF)'));
      await t.pumpAndSettle();
      expect(repo.lastReceiptAsHost, true);
    });

    testWidgets('refunding asks for an amount within what is left and a reason, then sends it', (t) async {
      final repo = FakeRentRepository()..paid = [online(canRefund: true)];
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: withOpener(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Paid'));
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Refund'));
      await t.pumpAndSettle();
      expect(find.text('Refund this payment'), findsOneWidget);
      await t.tap(find.text('Refund').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Give a reason'), findsOneWidget); // the amount defaults to what is refundable, the reason is required
      expect(repo.calls, isNot(contains('refund')));
      await t.enterText(find.byType(TextField).first, '99999');
      await t.enterText(find.byType(TextField).last, 'Paid twice by mistake');
      await t.tap(find.text('Refund').last);
      await t.pumpAndSettle();
      expect(find.textContaining('At most ₹7,500'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '2500');
      await t.tap(find.text('Refund').last);
      await t.pumpAndSettle();
      expect(repo.lastRefund, (paymentId: 'p1', amountPaise: 250000, reason: 'Paid twice by mistake'));
    });
  });

  group('paying rent online', () {
    Future<FakeRentRepository> open(WidgetTester t, FakeRentRepository repo) async {
      await pumpScreen(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => showRentPaySheet(context, invoice()), child: const Text('open')),
            ),
          ),
        ),
        overrides: over(repo),
        size: const Size(390, 1600),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the balance and the outcomes to simulate, then confirms only when the server says it was captured', (t) async {
      final repo = await open(t, FakeRentRepository());
      expect(find.text('Amount to pay'), findsOneWidget);
      expect(find.text('Pay successfully'), findsOneWidget);
      expect(repo.startCalls, 1);
      await t.tap(find.text('Pay ₹7,500'));
      await t.pump(); // the checkout call
      expect(find.text('Confirming with the bank…'), findsOneWidget);
      expect(find.text('Rent paid'), findsNothing); // never assumed: waiting for the server
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.text('Rent paid'), findsOneWidget);
      expect(repo.lastInstrument, 'DEMO_SUCCESS');
      expect(repo.calls, containsAllInOrder(['checkout:DEMO_SUCCESS', 'poll']));
    });

    testWidgets('keeps polling while the payment is pending, then confirms', (t) async {
      final repo = FakeRentRepository()
        ..pollResults = [
          RentOrder.fromJson(orderJson(status: 'PENDING')),
          RentOrder.fromJson(orderJson(status: 'PENDING')),
          RentOrder.fromJson(orderJson(status: 'CAPTURED')),
        ];
      await open(t, repo);
      await t.tap(find.text('Takes a moment'));
      await t.tap(find.text('Pay ₹7,500'));
      await t.pump();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 1200));
      }
      await t.pumpAndSettle();
      expect(repo.calls.where((c) => c == 'poll').length, 3);
      expect(find.text('Rent paid'), findsOneWidget);
    });

    testWidgets('a declined payment says so and starts a fresh order so the tenant can retry', (t) async {
      final repo = FakeRentRepository()
        ..pollResults = [RentOrder.fromJson(orderJson(status: 'FAILED', failure: 'Your bank declined the payment (demo)'))];
      await open(t, repo);
      await t.tap(find.text('Payment fails'));
      await t.tap(find.text('Pay ₹7,500'));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.textContaining("Payment didn't go through"), findsOneWidget);
      expect(find.textContaining('Your bank declined the payment (demo)'), findsOneWidget);
      expect(find.text('Rent paid'), findsNothing);
      expect(repo.startCalls, 2); // a failed order is final: a new one was started
      expect(find.text('Pay ₹7,500'), findsOneWidget); // ready to try again
    });

    testWidgets('cannot start when the invoice is already settled', (t) async {
      final repo = FakeRentRepository()..startError = ApiException(code: 'CONFLICT', message: 'This invoice is already paid', status: 409);
      await open(t, repo);
      expect(find.text('This invoice is already paid'), findsOneWidget);
      final button = t.widget<AppButton>(find.widgetWithText(AppButton, 'Pay ₹7,500'));
      expect(button.onPressed, isNull);
    });
  });

  group('the owner\'s rent', () {
    FakeRentRepository withOverdue() => FakeRentRepository()
      ..overdue = [
        invoice(overdue: true, days: 3, actions: const ['record_payment', 'add_line', 'void']),
      ]
      ..rollData = RentRoll.fromJson(rollJson(overdueCount: 1));

    testWidgets('shows the month at a glance and the overdue invoices', (t) async {
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: over(withOverdue(), user: owner),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      expect(find.text('Billed'), findsOneWidget);
      expect(find.text('₹22,500'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('3d overdue'), findsWidgets);
    });

    testWidgets('records a payment received outside the app', (t) async {
      final repo = withOverdue();
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao'));
      await t.pumpAndSettle();
      expect(find.text('Record payment'), findsOneWidget);
      await t.tap(find.text('Record payment'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cash'));
      await t.enterText(find.byType(TextField).first, '5000');
      await t.tap(find.text('Record'));
      await t.pumpAndSettle();
      expect(repo.calls, ['record']);
      expect(repo.lastRecord, (amountPaise: 500000, method: 'CASH', reference: ''));
    });

    testWidgets('refuses an amount larger than what is owed, before asking the server', (t) async {
      final repo = withOverdue();
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao'));
      await t.pumpAndSettle();
      await t.tap(find.text('Record payment'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '99999');
      await t.tap(find.text('Record'));
      await t.pumpAndSettle();
      expect(find.textContaining('more than the ₹7,500 still owed'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a paid invoice offers no recording', (t) async {
      final repo = FakeRentRepository()..overdue = [invoice(status: 'PAID', paid: 750000, actions: const [])];
      await pumpScreen(
        t,
        const HostRentScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Asha Rao'));
      await t.pumpAndSettle();
      expect(find.text('Record payment'), findsNothing);
      expect(find.textContaining('RCPT-2702-XYZ789'), findsOneWidget);
    });

    testWidgets('a guest cannot open the owner screen', (t) async {
      await pumpScreen(t, const HostRentScreen(), overrides: over(FakeRentRepository()));
      await t.pumpAndSettle();
      expect(find.text('Hosting is not set up'), findsOneWidget);
    });
  });
}
