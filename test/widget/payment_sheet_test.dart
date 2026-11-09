import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/features/bookings/presentation/payment_sheet.dart';

import '../support/support.dart';

class _Launcher extends StatelessWidget {
  const _Launcher(this.onResult);
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => onResult(await showPaymentSheet(context, booking())),
            child: const Text('Open'),
          ),
        ),
      );
}

FakeBookingRepository _repo() {
  final repo = FakeBookingRepository();
  repo.onStartPayment = () async => paymentOrder();
  repo.onDemoCheckout = (_) async => paymentOrder(status: 'PENDING');
  return repo;
}

Future<void> _open(WidgetTester tester, FakeBookingRepository repo, ValueChanged<bool> onResult) async {
  await pumpScreen(tester, _Launcher(onResult), overrides: baseOverrides(repo: repo));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initLocale);

  testWidgets('offers the amount, the methods and every demo outcome', (tester) async {
    final repo = _repo();
    await _open(tester, repo, (_) {});

    expect(find.text('Complete your payment'), findsOneWidget);
    expect(find.text('Amount to pay'), findsOneWidget);
    expect(find.text('₹2,520'), findsOneWidget);
    for (final m in ['UPI', 'Card', 'Net banking', 'Wallet']) {
      expect(find.text(m), findsOneWidget, reason: m);
    }
    for (final o in ['Pay successfully', 'Takes a moment', 'Payment fails', 'Never completes']) {
      expect(find.text(o), findsOneWidget, reason: o);
    }
    expect(find.text('Pay ₹2,520'), findsOneWidget);
    expect(repo.startPaymentCalls, 1);
  });

  testWidgets('success: the app waits for the server to confirm, never decides by itself', (tester) async {
    final repo = _repo();
    var polls = 0;
    repo.onDetail = () async => ++polls < 2 ? booking() : booking(status: 'CONFIRMED', actions: const []);
    bool? result;
    await _open(tester, repo, (r) => result = r);

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    expect(find.text('Confirming with the bank…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200)); // poll 1: still pending payment
    await tester.pump();
    expect(find.text('Confirming with the bank…'), findsOneWidget);
    expect(find.text("You're booked"), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200)); // poll 2: confirmed
    await tester.pumpAndSettle();
    expect(find.text("You're booked"), findsOneWidget);
    expect(find.textContaining('HB-ABC123'), findsOneWidget);

    await tester.tap(find.text('View booking'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('a network blip while waiting is not reported as a failed payment', (tester) async {
    final repo = _repo();
    var polls = 0;
    repo.onDetail = () async {
      polls++;
      if (polls == 1) throw ApiException(code: 'NETWORK', message: 'No connection');
      return booking(status: 'CONFIRMED', actions: const []);
    };
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200)); // poll 1: the network drops
    await tester.pump();
    expect(find.text("Payment didn't go through"), findsNothing);
    expect(find.text('Confirming with the bank…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200)); // poll 2: confirmed
    await tester.pumpAndSettle();
    expect(find.text("You're booked"), findsOneWidget);
    expect(repo.startPaymentCalls, 1, reason: 'no fresh order was started');
  });

  testWidgets('a poll that is refused (404) after paying says "still waiting", never "failed"', (tester) async {
    final repo = _repo();
    repo.onDetail = () async => throw ApiException(code: 'NOT_FOUND', message: 'gone', status: 404);
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Still waiting for the bank'), findsOneWidget);
    expect(find.text("Payment didn't go through"), findsNothing);
    expect(repo.startPaymentCalls, 1, reason: 'no second order while the first may be in flight');
  });

  testWidgets('a failure left over from an earlier attempt is not blamed on the new order', (tester) async {
    final repo = _repo();
    var polls = 0;
    repo.onDetail = () async {
      polls++;
      // the booking still reports the previous, already-failed payment (a different id) until the new one is captured
      return polls < 2 ? booking(payment: {'id': 'old-payment', 'status': 'FAILED', 'failureReason': 'Old decline', 'amountPaise': 252000}) : booking(status: 'CONFIRMED', actions: const []);
    };
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(find.text("Payment didn't go through"), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text("You're booked"), findsOneWidget);
  });

  testWidgets('the chosen outcome is what the bank is asked to do', (tester) async {
    final repo = _repo();
    String? asked;
    repo.onDemoCheckout = (i) async {
      asked = i;
      return paymentOrder(status: 'PENDING');
    };
    repo.onDetail = () async => booking();
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Payment fails'));
    await tester.pump();
    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    expect(asked, 'DEMO_FAIL');

    await tester.pump(const Duration(seconds: 45)); // run out the clock so no timer is left behind
    await tester.pumpAndSettle();
  });

  testWidgets('a declined payment says why, keeps the beds, and gets a fresh order ready for the retry', (tester) async {
    final repo = _repo();
    repo.onDetail = () async => booking(payment: {'id': 'p1', 'status': 'FAILED', 'failureReason': 'Insufficient funds', 'amountPaise': 252000});
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text("Payment didn't go through"), findsOneWidget);
    expect(find.textContaining('Insufficient funds.'), findsOneWidget);
    expect(find.textContaining('Your beds are still held'), findsOneWidget);
    expect(repo.startPaymentCalls, 2, reason: 'a failed order is final, so a new one is started for the retry');
    expect(find.text('Pay ₹2,520'), findsOneWidget);
  });

  testWidgets('if the booking stopped being payable meanwhile, say so instead of spinning', (tester) async {
    final repo = _repo();
    repo.onDetail = () async => booking(status: 'EXPIRED', actions: const []);
    await _open(tester, repo, (_) {});

    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Still waiting for the bank'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('if the order cannot be started the error is shown and Pay stays disabled', (tester) async {
    final repo = _repo();
    repo.onStartPayment = () async => throw ApiException(code: 'CONFLICT', message: 'This booking can no longer be paid.', status: 409);
    await _open(tester, repo, (_) {});

    expect(find.text('This booking can no longer be paid.'), findsOneWidget);
    await tester.tap(find.text('Pay ₹2,520'));
    await tester.pump();
    expect(find.text('Confirming with the bank…'), findsNothing);
  });
}
