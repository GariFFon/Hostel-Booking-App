import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/util/validators.dart';

void main() {
  group('email', () {
    test('accepts normal addresses', () {
      expect(Validators.email('asha@example.com'), isNull);
      expect(Validators.email('  a.b+c@sub.example.in  '), isNull);
    });
    test('rejects blanks and malformed input', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('no-at-sign'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a b@c.com'), isNotNull);
      expect(Validators.email('${'x' * 250}@e.com'), isNotNull);
    });
  });

  group('mobile', () {
    test('accepts Indian numbers in common shapes', () {
      for (final v in ['9876543210', '98765 43210', '+91 98765-43210', '09876543210', '919876543210']) {
        expect(Validators.mobile(v), isNull, reason: v);
      }
    });
    test('rejects numbers that cannot be mobile numbers', () {
      for (final v in ['', '12345', '5876543210', '98765432101', 'abcdefghij']) {
        expect(Validators.mobile(v), isNotNull, reason: v);
      }
    });
    test('optional allows empty but still checks what is typed', () {
      expect(Validators.mobile('', optional: true), isNull);
      expect(Validators.mobile('123', optional: true), isNotNull);
    });
    test('normalises to +91XXXXXXXXXX (the shape the backend accepts)', () {
      expect(Validators.normaliseMobile('98765 43210'), '+919876543210');
      expect(Validators.normaliseMobile('09876543210'), '+919876543210');
      expect(Validators.normaliseMobile('+91 98765-43210'), '+919876543210');
      expect(Validators.normaliseMobile(' nonsense '), 'nonsense');
    });
  });

  group('password and name', () {
    test('password length bounds', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('short'), isNotNull);
      expect(Validators.newPassword('longenough'), isNull);
      expect(Validators.newPassword('x' * 129), isNotNull);
    });
    test('full name', () {
      expect(Validators.fullName(' '), isNotNull);
      expect(Validators.fullName('A'), isNotNull);
      expect(Validators.fullName('Asha Rao'), isNull);
      expect(Validators.fullName('अनुप्रिया शर्मा'), isNull);
      expect(Validators.fullName('x' * 101), isNotNull);
    });
  });
}
