import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/bookings/data/booking_repository.dart';
import 'package:hostel_booking_app/features/bookings/domain/quote_models.dart';
import 'package:hostel_booking_app/features/bookings/presentation/checkout_args.dart';
import 'package:hostel_booking_app/features/bookings/presentation/checkout_screen.dart';

import '../support/support.dart';

CheckoutArgs _args({String genderPolicy = 'MIXED', String bookingMode = 'INSTANT', String roomGender = 'MIXED', int guests = 2}) => CheckoutArgs(
      hostel: hostel(genderPolicy: genderPolicy, bookingMode: bookingMode, roomGender: roomGender),
      checkIn: DateTime(2026, 12, 1),
      checkOut: DateTime(2026, 12, 4),
      guests: guests,
      items: const [RoomSelection('r1', 2)],
    );

class _PendingWithArgs extends PendingCheckout {
  @override
  CheckoutArgs? build() => _args();
}

Future<void> _tapCta(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

FakeBookingRepository _repo({int total = 252000}) {
  final repo = FakeBookingRepository();
  repo.onQuote = () async => Quote.fromJson(quoteJson(total: total));
  repo.onCreate = (_, _, _, _) async => booking();
  return repo;
}

void main() {
  setUpAll(initLocale);

  testWidgets('shows the stay, the itemised price and a pay button with the exact total', (tester) async {
    final repo = _repo();
    await pumpScreen(tester, CheckoutScreen(args: _args()), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Review and book'), findsOneWidget);
    expect(find.text('Palolem Beach Hostel'), findsOneWidget);
    expect(find.textContaining('3 nights'), findsWidgets);
    expect(find.text('6-bed dorm × 2'), findsOneWidget);
    expect(find.text('GST (5%)'), findsOneWidget);
    expect(find.text('Continue to payment · ₹2,520'), findsOneWidget);
    // The primary guest is prefilled from the account; the second is empty.
    expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsOneWidget);
    expect(find.text('+91  '), findsWidgets);
  });

  testWidgets('request-to-book stays say you are not charged yet', (tester) async {
    final repo = _repo();
    await pumpScreen(tester, CheckoutScreen(args: _args(bookingMode: 'APPROVAL')), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Request to book'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
    expect(find.textContaining('pay only if they accept'), findsOneWidget);
  });

  testWidgets('invalid details are caught on the device: nothing is sent', (tester) async {
    final repo = _repo();
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(user: const AppUser(id: 'u2', email: 'x@y.com'), repo: repo));
    await tester.pumpAndSettle();

    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();

    expect(repo.createKeys, isEmpty);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a mobile number'), findsOneWidget);
  });

  testWidgets('gendered stays require each guest gender before anything is sent', (tester) async {
    final repo = _repo();
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1, genderPolicy: 'MALE_ONLY')), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '').last, '98765 43210');
    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();

    expect(repo.createKeys, isEmpty);
    expect(find.text("Select this guest's gender"), findsOneWidget);
  });

  testWidgets('books with a normalised phone and the quoted total, then opens the booking ready to pay', (tester) async {
    final repo = _repo();
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();
    final phone = find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text == '9876543210');
    expect(phone, findsOneWidget, reason: 'phone is prefilled from the account without the +91');
    await tester.enterText(phone, '98765 43211');

    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();

    expect(repo.createKeys, hasLength(1));
    expect(repo.createPhones.single, '+919876543211');
    expect(repo.createExpected.single, 252000);
    expect(repo.createGuests.single.single.fullName, 'Asha Rao');
    expect(find.text('detail b1 pay=1'), findsOneWidget);
  });

  testWidgets('a price change is reported, not silently charged, and the retry uses a new idempotency key', (tester) async {
    final repo = _repo();
    var total = 252000;
    repo.onQuote = () async => Quote.fromJson(quoteJson(total: total));
    repo.onCreate = (_, expected, _, _) async {
      if (expected != 264600) {
        throw ApiException(code: 'PRICE_CHANGED', message: 'changed', status: 409, details: {'expectedTotalPaise': expected, 'totalPaise': 264600});
      }
      return booking();
    };
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();

    total = 264600; // the server now quotes the new price
    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();

    expect(find.textContaining('The price changed from ₹2,520 to ₹2,646'), findsOneWidget);
    expect(find.text('Continue to payment · ₹2,646'), findsOneWidget, reason: 'the page re-quoted');
    expect(find.text('detail b1 pay=1'), findsNothing);

    await _tapCta(tester, 'Continue to payment · ₹2,646');
    await tester.pumpAndSettle();
    expect(repo.createKeys, hasLength(2));
    expect(repo.createKeys.first, isNot(repo.createKeys.last), reason: 'a different request (new total) must not replay the old key');
    expect(find.text('detail b1 pay=1'), findsOneWidget);
  });

  testWidgets('retrying the identical request after a network error reuses the idempotency key (no double booking)', (tester) async {
    final repo = _repo();
    var fail = true;
    repo.onCreate = (_, _, _, _) async {
      if (fail) {
        fail = false;
        throw ApiException(code: 'NETWORK', message: 'No connection');
      }
      return booking();
    };
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();

    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach the server"), findsOneWidget);

    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();
    expect(repo.createKeys, hasLength(2));
    expect(repo.createKeys.first, repo.createKeys.last);
  });

  testWidgets('sold out says so and offers a way back', (tester) async {
    final repo = _repo();
    repo.onCreate = (_, _, _, _) async => throw ApiException(code: 'SOLD_OUT', message: 'x', status: 409);
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();

    await _tapCta(tester, 'Continue to payment · ₹2,520');
    await tester.pumpAndSettle();
    expect(find.textContaining('Someone just booked the last beds'), findsOneWidget);
    expect(find.text('Back to the property'), findsOneWidget);
  });

  testWidgets('a rejected coupon is explained and does not block booking', (tester) async {
    final repo = _repo();
    repo.onQuote = () async => Quote.fromJson(quoteJson(couponCode: 'OLD', couponValid: false));
    await pumpScreen(tester, CheckoutScreen(args: _args(guests: 1)), overrides: baseOverrides(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '').last, 'old');
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(repo.lastCouponCode, 'OLD', reason: 'codes are upper-cased');
    expect(find.text('This coupon has expired.'), findsOneWidget);
    expect(find.text('Continue to payment · ₹2,520'), findsOneWidget);
  });

  testWidgets('after the sign-in detour the router hands over no arguments, but the pending checkout is used', (tester) async {
    final repo = _repo();
    await pumpScreen(
      tester,
      const CheckoutScreen(args: null),
      overrides: [...baseOverrides(repo: repo), pendingCheckoutProvider.overrideWith(_PendingWithArgs.new)],
    );
    await tester.pumpAndSettle();
    expect(find.text('This checkout has expired'), findsNothing);
    expect(find.text('Palolem Beach Hostel'), findsOneWidget);
    expect(find.text('Continue to payment · ₹2,520'), findsOneWidget);
  });

  testWidgets('opening checkout without its arguments (app restarted) explains and goes home', (tester) async {
    await pumpScreen(tester, const CheckoutScreen(args: null), overrides: baseOverrides());
    expect(find.text('This checkout has expired'), findsOneWidget);
    await tester.tap(find.text('Back to search'));
    await tester.pumpAndSettle();
  });
}
