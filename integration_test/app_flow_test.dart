// Drives the real app on a simulator against a running local backend (seeded DB): browse, sign in through the Reserve detour,
// check out, pay with the demo gateway, manage the trip, then the host screens. Screenshots go to $SHOTS_DIR.
//
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hostel_booking_app/app.dart';
import 'package:hostel_booking_app/core/config/env.dart';
import 'package:hostel_booking_app/core/format/format.dart';
import 'package:hostel_booking_app/core/network/token_store.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/core/router/app_router.dart';
import 'package:hostel_booking_app/features/hostels/presentation/hostel_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokens implements TokenStore {
  TokenPair? _t;
  @override
  Future<TokenPair?> read() async => _t;
  @override
  Future<void> write(TokenPair tokens) async => _t = tokens;
  @override
  Future<void> clear() async => _t = null;
}

const _slug = 'palolem-beach-nomads-goa';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(WidgetTester t, Finder f, {int seconds = 30, String? why}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 250));
      if (f.evaluate().isNotEmpty) return;
    }
    // ignore: avoid_print
    print('TIMEOUT waiting for ${why ?? f.toString()}');
    await binding.takeScreenshot('TIMEOUT_${(why ?? 'x').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}');
    expect(f, findsWidgets, reason: why);
  }

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot(name);
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    await pumpUntil(t, f, why: 'text "$text"');
    final target = last ? f.last : f.first;
    await t.ensureVisible(target);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(target);
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('guest books and pays; host manages', (t) async {
    await initializeDateFormatting('en_IN');
    Intl.defaultLocale = 'en_IN';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          envProvider.overrideWithValue(Env.dev()),
          sharedPrefsProvider.overrideWithValue(prefs),
          tokenStoreProvider.overrideWithValue(_MemoryTokens()),
        ],
        child: const HostelApp(),
      ),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(HostelApp)));
    GoRouter router() => container.read(routerProvider);

    // 1. Explore, signed out.
    await t.pump(const Duration(seconds: 4));
    await shot(t, '01_explore');
    await pumpUntil(t, find.byType(HostelCardView), why: 'explore list');

    // 2. A property page with dates already chosen (as if picked in search).
    final ci = today().add(const Duration(days: 95));
    final co = ci.add(const Duration(days: 2));
    router().go('/hostel/$_slug?checkIn=${toApiDate(ci)}&checkOut=${toApiDate(co)}&guests=1');
    await pumpUntil(t, find.text('Palolem Beach Nomads'), why: 'hostel page');
    await shot(t, '02_hostel');

    // 3. Choose a bed, then Reserve while signed out: expect the sign-in detour.
    final more = find.bySemanticsLabel(RegExp('More (beds|rooms)'));
    await pumpUntil(t, more, why: 'room stepper');
    // Centre the row first: at the top edge it sits under the floating back/heart buttons.
    await Scrollable.ensureVisible(t.element(more.last), alignment: 0.5);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(more.last);
    await t.pump(const Duration(milliseconds: 500));
    await pumpUntil(t, find.text('Reserve'), why: 'reserve');
    await shot(t, '03_room_selected');
    await pumpUntil(t, find.textContaining('incl. taxes'), why: 'live quote');
    await t.tap(find.text('Reserve'));
    await pumpUntil(t, find.text('Sign in'), why: 'login screen');
    await shot(t, '04_login_detour');

    // 4. Sign in: we must land on checkout with the selection intact (not on "checkout expired").
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'guest1@hostel.dev');
    await t.enterText(fields.at(1), 'Password@123');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done); // the password field submits the form
    await pumpUntil(t, find.text('Review and book'), why: 'checkout after sign-in');
    expect(find.text('This checkout has expired'), findsNothing);
    await shot(t, '05_checkout');

    // 5. Fill the contact number and book.
    final phone = find.byType(TextFormField).at(find.byType(TextFormField).evaluate().length - 3); // phone, notes, coupon
    await t.ensureVisible(phone);
    await t.enterText(phone, '98765 43210');
    await t.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, '06_checkout_filled');
    await tapText(t, find.textContaining('Continue to payment').evaluate().isNotEmpty ? (find.textContaining('Continue to payment').evaluate().first.widget as Text).data! : 'Confirm booking');

    // 6. Booking page with the payment sheet open.
    await pumpUntil(t, find.text('Complete your payment'), why: 'payment sheet');
    await shot(t, '07_payment_sheet');
    await t.tap(find.textContaining('Pay ₹').last);
    await pumpUntil(t, find.text("You're booked"), seconds: 60, why: 'confirmation');
    await shot(t, '08_paid');
    await t.tap(find.text('View booking'));
    await t.pump(const Duration(milliseconds: 800));
    await pumpUntil(t, find.text('Cancel booking'), why: 'booking detail actions');
    await shot(t, '09_booking_detail');

    // 7. Trips tab, Account tab, notifications.
    router().go('/trips');
    await pumpUntil(t, find.text('Upcoming'), why: 'trips');
    await pumpUntil(t, find.textContaining('Palolem Beach Nomads'), why: 'trip card');
    await shot(t, '10_trips');
    router().go('/account');
    await pumpUntil(t, find.text('Personal details'), why: 'account');
    await shot(t, '11_account');
    router().push('/notifications');
    await pumpUntil(t, find.text('Notifications'), why: 'notifications');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '12_notifications');
    router().pop();
    await t.pump(const Duration(milliseconds: 500));

    // 8. Cancel the trip (shows the refund first).
    router().go('/trips');
    await pumpUntil(t, find.textContaining('Palolem Beach Nomads'), why: 'trip card again');
    await t.tap(find.textContaining('Palolem Beach Nomads').first);
    await pumpUntil(t, find.text('Cancel booking'), why: 'detail');
    await tapText(t, 'Cancel booking');
    await pumpUntil(t, find.text('Cancel this booking?'), why: 'cancel sheet');
    await pumpUntil(t, find.text('Refund to you'), why: 'refund preview');
    await shot(t, '13_cancel_sheet');
    await t.tap(find.text('Cancel booking').last);
    await pumpUntil(t, find.text('You cancelled this booking'), why: 'cancelled banner');
    await shot(t, '14_cancelled');

    // 9. Saved tab (heart a property first).
    router().go('/');
    await pumpUntil(t, find.byType(HostelCardView), why: 'explore');
    await t.tap(find.bySemanticsLabel(RegExp('^Save ')).first);
    await t.pump(const Duration(seconds: 1));
    router().go('/saved');
    await pumpUntil(t, find.byType(HostelCardView), why: 'saved');
    await shot(t, '15_saved');

    // 10. Sign out, sign in as a host, browse the host screens.
    router().go('/account');
    await pumpUntil(t, find.text('Personal details'), why: 'account again');
    await t.scrollUntilVisible(find.text('Sign out'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Sign out'));
    await pumpUntil(t, find.text('Stay signed in'), why: 'sign-out confirmation');
    await t.tap(find.text('Sign out').last);
    await pumpUntil(t, find.text('Sign in to book'), why: 'signed out');
    await shot(t, '16_signed_out_account');
    router().go('/login?next=%2Fhost');
    await pumpUntil(t, find.text('Sign in'), why: 'login');
    final f2 = find.byType(TextFormField);
    await t.enterText(f2.at(0), 'owner1@hostel.dev');
    await t.enterText(f2.at(1), 'Password@123');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(t, find.text('Hosting'), why: 'host home');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '17_host_home');
    router().push('/host/bookings?tab=upcoming');
    await pumpUntil(t, find.text('Bookings'), why: 'host bookings');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '18_host_bookings');
    router().pop();
    router().push('/host/listings');
    await pumpUntil(t, find.text('Your listings'), why: 'host listings');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '19_host_listings');
    router().pop();
    router().push('/host/reviews');
    await pumpUntil(t, find.text('Reviews'), why: 'host reviews');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '20_host_reviews');

    // 11. A property's full review list.
    router().go('/hostel/$_slug/reviews');
    await pumpUntil(t, find.text('Reviews'), why: 'all reviews');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '21_all_reviews');
  });
}
