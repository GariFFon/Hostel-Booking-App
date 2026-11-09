import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/router/routes.dart';

void main() {
  group('safeNext only lets same-app paths through', () {
    test('accepts app paths', () {
      expect(Routes.safeNext('/trips/abc?pay=1'), '/trips/abc?pay=1');
      expect(Routes.safeNext('/'), '/');
    });
    test('rejects anything that could leave the app', () {
      for (final v in [null, '', 'trips', '//evil.com', 'https://evil.com', '/redirect?to=https://evil.com', 'javascript:alert(1)']) {
        expect(Routes.safeNext(v), isNull, reason: '$v');
      }
    });
  });

  test('tabs are public but their detail pages need a session', () {
    expect(Routes.needsSignIn(Routes.explore), isFalse);
    expect(Routes.needsSignIn(Routes.saved), isFalse);
    expect(Routes.needsSignIn(Routes.trips), isFalse);
    expect(Routes.needsSignIn(Routes.account), isFalse);
    expect(Routes.needsSignIn('/hostel/some-slug'), isFalse);
    expect(Routes.needsSignIn(Routes.checkout), isTrue);
    expect(Routes.needsSignIn('/trips/b1'), isTrue);
    expect(Routes.needsSignIn(Routes.notifications), isTrue);
    expect(Routes.needsSignIn(Routes.profile), isTrue);
    expect(Routes.needsSignIn(Routes.host), isTrue);
    expect(Routes.needsSignIn('/host/bookings/b1'), isTrue);
  });

  test('hostel links carry valid stays only', () {
    expect(Routes.hostel('goa-stay'), '/hostel/goa-stay');
    expect(Routes.hostel('goa-stay', checkIn: DateTime(2026, 12, 1), checkOut: DateTime(2026, 12, 4), guests: 2), '/hostel/goa-stay?checkIn=2026-12-01&checkOut=2026-12-04&guests=2');
    expect(Routes.hostel('goa-stay', checkIn: DateTime(2026, 12, 1)), '/hostel/goa-stay'); // half a range is dropped
    expect(Routes.booking('b1'), '/trips/b1');
    expect(Routes.booking('b1', pay: true), '/trips/b1?pay=1');
  });
}
