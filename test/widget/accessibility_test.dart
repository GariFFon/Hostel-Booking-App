import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/account/presentation/account_screen.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/auth/presentation/login_screen.dart';
import 'package:hostel_booking_app/features/bookings/application/booking_providers.dart';
import 'package:hostel_booking_app/features/bookings/data/booking_repository.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/bookings/domain/quote_models.dart';
import 'package:hostel_booking_app/features/bookings/presentation/booking_detail_screen.dart';
import 'package:hostel_booking_app/features/bookings/presentation/checkout_args.dart';
import 'package:hostel_booking_app/features/bookings/presentation/checkout_screen.dart';
import 'package:hostel_booking_app/features/host/data/host_repository.dart';
import 'package:hostel_booking_app/features/host/domain/host_models.dart';
import 'package:hostel_booking_app/features/host/presentation/host_home_screen.dart';
import 'package:hostel_booking_app/features/notifications/application/notification_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/support.dart';

class _MockHostRepo extends Mock implements HostRepository {}

/// The real notifier polls every 60 s; a periodic timer would outlive the test.
class _QuietUnread extends UnreadCountNotifier {
  @override
  Future<int> build() async => 3;
}

const _owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Meera', roles: [UserRole.owner]);

/// Flutter's own accessibility guidelines on the screens people actually use: tap targets, labelled controls and text contrast,
/// in light and dark. A failure here names the offending widget.
void main() {
  setUpAll(initLocale);

  final themes = [Brightness.light, Brightness.dark];

  Future<void> checkAll(WidgetTester t, {required String name}) async {
    final handle = t.ensureSemantics();
    await expectLater(t, meetsGuideline(androidTapTargetGuideline), reason: '$name: Android tap targets');
    await expectLater(t, meetsGuideline(iOSTapTargetGuideline), reason: '$name: iOS tap targets');
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline), reason: '$name: every tappable is labelled');
    await expectLater(t, meetsGuideline(textContrastGuideline), reason: '$name: text contrast');
    handle.dispose();
  }

  for (final b in themes) {
    group('${b.name} theme', () {
      testWidgets('sign in', (t) async {
        SharedPreferences.setMockInitialValues({});
        // Wider than a phone: the test font (Ahem) makes every glyph a wide square, which would overflow the footer row for no real reason.
        await pumpScreen(t, const LoginScreen(), overrides: baseOverrides(user: null), brightness: b, size: const Size(700, 900));
        await t.pumpAndSettle();
        await checkAll(t, name: 'login');
      });

      testWidgets('checkout', (t) async {
        final repo = FakeBookingRepository()..onQuote = (() async => Quote.fromJson(quoteJson()));
        await pumpScreen(
          t,
          CheckoutScreen(args: CheckoutArgs(hostel: hostel(), checkIn: DateTime(2026, 12, 1), checkOut: DateTime(2026, 12, 4), guests: 2, items: const [RoomSelection('r1', 2)])),
          overrides: baseOverrides(repo: repo),
          brightness: b,
        );
        await t.pumpAndSettle();
        await checkAll(t, name: 'checkout');
      });

      testWidgets('booking page (pay + cancel)', (t) async {
        final bk = Booking.fromJson(bookingJson(holdExpiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String()));
        await pumpScreen(
          t,
          const BookingDetailScreen(id: 'b1'),
          overrides: [...baseOverrides(), bookingDetailProvider.overrideWith((ref, id) async => bk)],
          brightness: b,
        );
        await t.pump();
        await t.pump();
        await checkAll(t, name: 'booking page');
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });

      testWidgets('account', (t) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await pumpScreen(t, const AccountScreen(), overrides: [...baseOverrides(user: guestUser), sharedPrefsProvider.overrideWithValue(prefs), unreadCountProvider.overrideWith(_QuietUnread.new)], brightness: b);
        await t.pumpAndSettle();
        await checkAll(t, name: 'account');
      });

      testWidgets('host dashboard', (t) async {
        final repo = _MockHostRepo();
        when(() => repo.bookings(when: any(named: 'when'), status: any(named: 'status'), hostelId: any(named: 'hostelId'), cursor: any(named: 'cursor'))).thenAnswer((_) async => Paged.empty<BookingSummary>());
        when(repo.earnings).thenAnswer((_) async => Earnings.fromJson({'settled': {'bookings': 3, 'ownerPayablePaise': 1234500}, 'upcoming': {'bookings': 2, 'expectedOwnerPaise': 560000}, 'byHostel': <dynamic>[]}));
        final List<Override> o = [...baseOverrides(user: _owner), hostRepositoryProvider.overrideWithValue(repo)];
        await pumpScreen(t, const HostHomeScreen(), overrides: o, brightness: b);
        await t.pumpAndSettle();
        await checkAll(t, name: 'host dashboard');
      });
    });
  }
}
