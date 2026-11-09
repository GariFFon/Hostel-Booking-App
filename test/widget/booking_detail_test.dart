import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/features/bookings/application/booking_providers.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/bookings/presentation/booking_detail_screen.dart';
import 'package:hostel_booking_app/features/host/application/host_providers.dart';

import '../support/support.dart';

Future<void> _show(WidgetTester tester, Booking b, {bool host = false, double textScale = 1}) async {
  await pumpScreen(
    tester,
    BookingDetailScreen(id: 'b1', host: host),
    textScale: textScale,
    overrides: [
      ...baseOverrides(),
      bookingDetailProvider.overrideWith((ref, id) async => b),
      hostBookingDetailProvider.overrideWith((ref, id) async => b),
    ],
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // stops the 1 Hz countdown ticker
  await tester.pump();
}

void main() {
  setUpAll(initLocale);

  testWidgets('guest: awaiting payment shows the countdown and exactly the actions the server allows', (tester) async {
    final json = bookingJson(holdExpiresAt: DateTime.now().add(const Duration(minutes: 14, seconds: 30)).toUtc().toIso8601String());
    await _show(tester, Booking.fromJson(json));

    expect(find.text('HB-ABC123'), findsOneWidget);
    expect(find.text('Palolem Beach Hostel'), findsOneWidget);
    expect(find.textContaining('Pay within 14:'), findsOneWidget);
    expect(find.text('Pay ₹2,520'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(find.text('Accept request'), findsNothing);
    expect(find.text('Write a review'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('guest: a confirmed stay with no actions has no action bar at all', (tester) async {
    await _show(tester, booking(status: 'CONFIRMED', actions: const []));
    expect(find.text("You're booked"), findsOneWidget);
    expect(find.textContaining('Pay '), findsNothing);
    expect(find.text('Cancel booking'), findsNothing);
  });

  testWidgets('guest: after the stay, the only offer is to review it', (tester) async {
    await _show(tester, booking(status: 'COMPLETED', actions: const ['review']));
    expect(find.text('Stay completed'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);
  });

  testWidgets('host: a request shows accept and decline, and never a pay button', (tester) async {
    await _show(tester, booking(status: 'PENDING_APPROVAL', actions: const ['approve', 'reject'], viewer: 'OWNER'), host: true);
    expect(find.text('Needs your decision'), findsOneWidget);
    expect(find.text('Accept request'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.textContaining('Pay '), findsNothing);
  });

  testWidgets('a status from a newer backend renders instead of crashing', (tester) async {
    await _show(tester, Booking.fromJson(bookingJson(status: 'AWAITING_KYC', actions: ['teleport'])));
    expect(tester.takeException(), isNull);
    expect(find.text('HB-ABC123'), findsOneWidget);
    expect(find.text('Unknown'), findsWidgets);
  });

  testWidgets('worst case: a very long property name at 200% text on a small phone does not overflow', (tester) async {
    final long = 'The Extraordinarily Long-Named Backpackers Beachfront Hostel & Surf Retreat ${'Palolem ' * 8}';
    await pumpScreen(
      tester,
      const BookingDetailScreen(id: 'b1'),
      size: const Size(320, 640),
      textScale: 2,
      overrides: [
        ...baseOverrides(),
        bookingDetailProvider.overrideWith((ref, id) async => Booking.fromJson(bookingJson(hostelName: long))),
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('offline: says so in words and can retry', (tester) async {
    await pumpScreen(
      tester,
      const BookingDetailScreen(id: 'b1'),
      overrides: [
        ...baseOverrides(),
        bookingDetailProvider.overrideWith((ref, id) async => throw ApiException(code: 'NETWORK', message: 'No connection')),
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
