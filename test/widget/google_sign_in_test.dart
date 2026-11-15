import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/auth/data/google_signer.dart';
import 'package:hostel_booking_app/features/auth/presentation/login_screen.dart';

import '../support/support.dart';

class _Signer implements GoogleSigner {
  _Signer(this.result);
  final Future<String?> Function() result;
  int calls = 0;
  @override
  Future<String?> idToken() {
    calls++;
    return result();
  }
}

class _Session extends FakeSession {
  _Session() : super(null);
  String? token;
  Object? failWith;

  @override
  Future<void> signInWithGoogle(String idToken) async {
    if (failWith != null) throw failWith!;
    token = idToken;
  }
}

void main() {
  setUpAll(initLocale);

  Future<_Session> open(WidgetTester t, _Signer signer, {Object? failWith}) async {
    final session = _Session()..failWith = failWith;
    await pumpScreen(
      t,
      const LoginScreen(),
      size: const Size(700, 900),
      overrides: [sessionProvider.overrideWith(() => session), googleSignerProvider.overrideWithValue(signer)],
    );
    await t.pumpAndSettle();
    return session;
  }

  testWidgets('the sign-in screen offers Google and hands the ID token to the session', (t) async {
    final signer = _Signer(() async => 'google-id-token-abcdefghijklmnop');
    final session = await open(t, signer);
    expect(find.text('Continue with Google'), findsOneWidget);
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(signer.calls, 1);
    expect(session.token, 'google-id-token-abcdefghijklmnop');
  });

  testWidgets('closing the Google sheet is silent: no error, nothing sent', (t) async {
    final signer = _Signer(() async => null);
    final session = await open(t, signer);
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(session.token, isNull);
    expect(find.textContaining("didn't work"), findsNothing);
  });

  testWidgets('a platform failure is explained in words and email sign-in stays available', (t) async {
    final signer = _Signer(() async => throw StateError('DEVELOPER_ERROR 10'));
    await open(t, signer);
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.textContaining("Google sign-in didn't work"), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('DEVELOPER_ERROR'), findsNothing, reason: 'internal codes are never shown');
  });

  testWidgets('a server refusal shows the server message', (t) async {
    final signer = _Signer(() async => 'google-id-token-abcdefghijklmnop');
    await open(
      t,
      signer,
      failWith: ApiException(code: 'UNAUTHENTICATED', message: 'x', status: 401),
    );
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('Please sign in again to continue.'), findsOneWidget);
  });
}
