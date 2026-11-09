import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/features/bookings/application/stay_selection.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/bookings/domain/quote_models.dart';
import 'package:hostel_booking_app/features/bookings/presentation/price_lines.dart';

import '../support/support.dart';

void main() {
  setUpAll(initLocale);
  stayHashContract();

  group('Booking', () {
    test('parses the backend shape, including snake_case actions', () {
      final b = Booking.fromJson(bookingJson(actions: ['pay', 'cancel', 'check_in', 'no_show', 'review']));
      expect(b.status, BookingStatus.pendingPayment);
      expect(b.checkIn, DateTime(2026, 12, 1));
      expect(b.nights, 3);
      expect(b.pricing.totalPaise, 252000);
      expect(b.actions, [BookingAction.pay, BookingAction.cancel, BookingAction.checkIn, BookingAction.noShow, BookingAction.review]);
      expect(b.can(BookingAction.pay), isTrue);
      expect(b.can(BookingAction.approve), isFalse);
    });

    test('a status or action added by a newer backend degrades to unknown instead of crashing', () {
      final b = Booking.fromJson(bookingJson(status: 'AWAITING_KYC', actions: ['pay', 'teleport'], viewer: 'SUPERVISOR'));
      expect(b.status, BookingStatus.unknown);
      expect(b.viewer, ViewerRole.unknown);
      expect(b.actions, [BookingAction.pay, BookingAction.unknown]);
      expect(b.status.label, 'Unknown');
    });

    test('optional blocks may be missing', () {
      final b = Booking.fromJson(bookingJson());
      expect(b.payment, isNull);
      expect(b.refund, isNull);
      expect(b.cancellation, isNull);
      expect(b.timeline, isEmpty);
      expect(b.holdExpiresAt, isNull);
    });

    test('status helpers match how the UI groups bookings', () {
      expect(BookingStatus.pendingPayment.isPending, isTrue);
      expect(BookingStatus.confirmed.isLive, isTrue);
      expect(BookingStatus.confirmed.isPending, isFalse);
      expect(BookingStatus.expired.isCancelledLike, isTrue);
      expect(BookingStatus.completed.isLive, isFalse);
    });
  });

  group('price lines', () {
    test('quote: items, GST and total line up with the backend numbers', () {
      final q = Quote.fromJson(quoteJson());
      final lines = quotePriceLines(q);
      expect(lines.map((l) => l.label), ['6-bed dorm × 2', 'GST (5%)']);
      expect(lines.first.paise, 240000);
      expect(lines.first.detail, '₹400 each × 3 nights');
      expect(lines.last.paise, 12000);
      expect(q.totalPaise, 252000);
    });

    test('quote: a valid coupon adds a discount line, an invalid one does not', () {
      final good = quoteJson(couponCode: 'SAVE100')..['discountPaise'] = 10000;
      expect(quotePriceLines(Quote.fromJson(good)).map((l) => l.label), contains('Discount (SAVE100)'));
      final bad = Quote.fromJson(quoteJson(couponCode: 'OLD', couponValid: false));
      expect(bad.couponApplied, isFalse);
      expect(bad.coupon?.message, 'This coupon has expired.');
      expect(quotePriceLines(bad).any((l) => l.discount), isFalse);
    });

    test('booking: single unit has no "each"', () {
      final json = bookingJson();
      ((json['items'] as List).first as Map)['units'] = 1;
      ((json['items'] as List).first as Map)['lineTotalPaise'] = 120000;
      final lines = bookingPriceLines(Booking.fromJson(json));
      expect(lines.first.detail, '₹400 × 3 nights');
    });
  });
}

void stayHashContract() {
  group('StaySelection', () {
    test('equal selections hash equal whatever order the rooms were added in', () {
      const a = StaySelection(units: {'a': 1, 'b': 2});
      const b = StaySelection(units: {'b': 2, 'a': 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
