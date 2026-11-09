import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/format/format.dart';
import 'package:hostel_booking_app/features/bookings/presentation/price_lines.dart';

import '../support/support.dart';

void main() {
  setUpAll(initLocale);

  group('money (integer paise, lakh grouping)', () {
    test('whole rupees drop the decimals', () {
      expect(money(0), '₹0');
      expect(money(89900), '₹899');
      expect(money(12345600), '₹1,23,456');
    });
    test('paise are kept when present', () {
      expect(money(125050), '₹1,250.50');
      expect(money(5), '₹0.05');
    });
    test('null is an em dash and discounts get a real minus', () {
      expect(money(null), '—');
      expect(moneyOff(20000), '−₹200');
      expect(moneyOff(-20000), '−₹200');
    });
  });

  test('plural never hard-codes the noun', () {
    expect(plural(1, 'night'), '1 night');
    expect(plural(3, 'night'), '3 nights');
    expect(plural(1284, 'review'), '1,284 reviews');
    expect(plural(2, 'guest', 'guests'), '2 guests');
  });

  test('dates are calendar dates, never shifted by time zone', () {
    final d = parseDate('2026-12-01');
    expect((d.year, d.month, d.day, d.hour), (2026, 12, 1, 0));
    expect(toApiDate(d), '2026-12-01');
    expect(toApiDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(nightsBetween(DateTime(2026, 12, 30, 23, 59), DateTime(2027, 1, 2, 1)), 3);
  });

  test('ranges collapse within a month and spell out across months', () {
    final now = DateTime.now().year;
    expect(fmtRange(DateTime(now, 3, 12), DateTime(now, 3, 15)), '12–15 Mar');
    expect(fmtRange(DateTime(now, 2, 28), DateTime(now, 3, 2)), '28 Feb – 2 Mar');
    expect(fmtRange(DateTime(2031, 3, 12), DateTime(2031, 3, 15)), '12–15 Mar 2031');
  });

  test('clock and countdown', () {
    expect(fmtClock('14:00'), '2:00 PM');
    expect(fmtClock('00:30'), '12:30 AM');
    expect(fmtClock('12:00'), '12:00 PM');
    expect(fmtClock('soon'), 'soon');
    expect(fmtCountdown(const Duration(minutes: 14, seconds: 5)), '14:05');
    expect(fmtCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(fmtCountdown(const Duration(seconds: -4)), '00:00');
  });

  test('humanize keeps unknown enum values readable', () {
    expect(humanize('PENDING_PAYMENT'), 'Pending payment');
    expect(humanize('pendingPayment'), 'Pending payment');
    expect(humanize(''), '');
  });

  test('initials are grapheme-safe', () {
    expect(initials('Asha Rao'), 'AR');
    expect(initials('Madonna'), 'M');
    expect(initials('  '), '?');
    expect(initials(null), '?');
    expect(initials('👩‍💻 Dev'), '👩‍💻D');
  });

  test('GST rate prints without noise', () {
    expect(fmtBps(500), '5%');
    expect(fmtBps(1800), '18%');
    expect(fmtBps(1250), '12.5%');
    expect(fmtBps(0), '0%');
  });
}
