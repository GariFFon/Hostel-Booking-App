import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/bookings/presentation/booking_card.dart';

import '../support/support.dart';

BookingSummary _summary({String name = 'Palolem Beach Hostel', String? guest, int total = 252000, String status = 'CONFIRMED', int nights = 3, int guests = 2}) =>
    BookingSummary.fromJson({
      'id': 'b1',
      'code': 'HB-ABC123',
      'status': status,
      'hostel': {'id': 'h1', 'name': name, 'city': 'Goa'},
      'checkIn': '2026-12-01',
      'checkOut': '2026-12-04',
      'nights': nights,
      'guestsCount': guests,
      'totalPaise': total,
      'guestName': guest,
      'createdAt': '2026-11-10T10:00:00.000Z',
    });

void main() {
  setUpAll(initLocale);

  final worst = <String, BookingSummary>{
    'normal': _summary(),
    'very long name': _summary(name: 'The Extraordinarily Long-Named Backpackers Beachfront Hostel & Surf Retreat ${'Palolem ' * 10}'),
    'one-letter name': _summary(name: 'A'),
    'unbroken string': _summary(name: 'W' * 120),
    'emoji and Devanagari': _summary(name: '🏖️ पालोलेम बीच हॉस्टल 🏄‍♀️', guest: 'अनुप्रिया शर्मा 👩‍💻'),
    'huge total': _summary(total: 99999999900),
    'free': _summary(total: 0),
    'one night one guest': _summary(nights: 1, guests: 1),
    'many nights': _summary(nights: 365),
    'unknown status': _summary(status: 'BRAND_NEW_STATUS'),
    'long guest name (host view)': _summary(guest: 'Maximilian Alexander Fitzgerald-Montgomery the Third ${'Smith ' * 6}'),
  };

  for (final scale in [1.0, 2.0]) {
    testWidgets('no overflow for any worst-case row at 320 px wide and ${scale * 100}% text', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final e in worst.entries) ...[
                BookingCard(booking: e.value, showGuest: true, onTap: () {}),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        overrides: baseOverrides(),
        size: const Size(320, 640),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      // Scroll through all of them so every card is actually laid out.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'after scrolling $i');
      }
    });
  }

  testWidgets('free bookings read "Free", not ₹0, and a tap is reported', (tester) async {
    var taps = 0;
    await pumpScreen(tester, Scaffold(body: BookingCard(booking: _summary(total: 0), onTap: () => taps++)), overrides: baseOverrides());
    expect(find.text('Free'), findsOneWidget);
    await tester.tap(find.byType(BookingCard));
    expect(taps, 1);
  });

  testWidgets('dark theme renders the same worst case', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: BookingCard(booking: _summary(name: 'W' * 120, guest: 'G' * 80), showGuest: true, onTap: () {})),
      overrides: baseOverrides(),
      size: const Size(320, 640),
      textScale: 2,
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
