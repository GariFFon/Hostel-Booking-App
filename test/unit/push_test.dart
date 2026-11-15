import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/core/router/app_router.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/notifications/application/push_coordinator.dart';
import 'package:hostel_booking_app/features/notifications/application/push_registration.dart';
import 'package:hostel_booking_app/features/notifications/data/notification_repository.dart';
import 'package:hostel_booking_app/features/notifications/data/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/support.dart';

class _FakePush implements PushService {
  _FakePush({this.token = 'tok-1', this.isAvailable = true});
  final String? token;
  final bool isAvailable;
  PushPayload? launch;
  int starts = 0;
  final tokens = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushPayload>.broadcast();
  final openedController = StreamController<PushPayload>.broadcast();

  @override
  bool get available => isAvailable;
  @override
  String get platform => 'ANDROID';
  @override
  Future<String?> start() async {
    starts++;
    return token;
  }

  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<PushPayload> get foreground => foregroundController.stream;
  @override
  Stream<PushPayload> get opened => openedController.stream;
  @override
  Future<PushPayload?> launchedBy() async => launch;
}

class _Repo implements NotificationRepository {
  final registered = <String>[];
  final removed = <String>[];
  bool offline = false;

  @override
  Future<String> registerDevice({required String platform, required String pushToken}) async {
    if (offline) throw Exception('offline');
    registered.add(pushToken);
    return 'dev-${registered.length}';
  }

  @override
  Future<void> removeDevice(String id) async {
    if (offline) throw Exception('offline');
    removed.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

PushPayload payload(String type, [Map<String, String> extra = const {}]) =>
    PushPayload(type: type, data: {'type': type, 'notificationId': 'n1', ...extra}, title: 'T', body: 'B');

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late _Repo repo;
  late _FakePush push;
  late GoRouter router;

  ProviderContainer container({bool signedIn = true, _FakePush? service}) {
    SharedPreferences.setMockInitialValues({});
    push = service ?? _FakePush();
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/:a',
          builder: (_, _) => const SizedBox(),
          routes: [GoRoute(path: ':b', builder: (_, _) => const SizedBox())],
        ),
      ],
    );
    final c = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => FakeSession(signedIn ? guestUser : null)),
        notificationRepositoryProvider.overrideWithValue(repo),
        pushServiceProvider.overrideWithValue(push),
        routerProvider.overrideWithValue(router),
      ],
    );
    return c;
  }

  setUp(() => repo = _Repo());

  Future<ProviderContainer> start({bool signedIn = true, _FakePush? service}) async {
    final c = container(signedIn: signedIn, service: service);
    final prefs = await SharedPreferences.getInstance();
    final withPrefs = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith(() => FakeSession(signedIn ? guestUser : null)),
        notificationRepositoryProvider.overrideWithValue(repo),
        pushServiceProvider.overrideWithValue(push),
        routerProvider.overrideWithValue(router),
      ],
    );
    c.dispose();
    await withPrefs.read(sessionProvider.future);
    withPrefs.listen(pushCoordinatorProvider, (_, _) {});
    await settle();
    return withPrefs;
  }

  group('registering this phone', () {
    test('asks permission and registers the token once someone is signed in', () async {
      final c = await start();
      addTearDown(c.dispose);
      expect(push.starts, 1);
      expect(repo.registered, ['tok-1']);
    });

    test('does nothing while signed out, or when push is not available on this build', () async {
      final out = await start(signedIn: false);
      addTearDown(out.dispose);
      expect(push.starts, 0);
      expect(repo.registered, isEmpty);

      final none = await start(service: _FakePush(isAvailable: false));
      addTearDown(none.dispose);
      expect(repo.registered, isEmpty);
    });

    test('a refused permission (no token) registers nothing and does not crash', () async {
      final c = await start(service: _FakePush(token: null));
      addTearDown(c.dispose);
      expect(repo.registered, isEmpty);
    });

    test('registers again when Firebase rotates the token', () async {
      final c = await start();
      addTearDown(c.dispose);
      push.tokens.add('tok-2');
      await settle();
      expect(repo.registered, ['tok-1', 'tok-2']);
    });

    test('a server that cannot be reached does not break start-up', () async {
      repo.offline = true;
      final c = await start();
      addTearDown(c.dispose);
      expect(repo.registered, isEmpty);
    });
  });

  group('signing out', () {
    test('removes this phone from the account first, so the next person does not get these notifications', () async {
      final c = await start();
      addTearDown(c.dispose);
      await c.read(pushRegistrationProvider).forget();
      expect(repo.removed, ['dev-1']);
      await c.read(pushRegistrationProvider).forget(); // already forgotten: nothing more to send
      expect(repo.removed, ['dev-1']);
    });

    test('is best effort: offline it still finishes', () async {
      final c = await start();
      addTearDown(c.dispose);
      repo.offline = true;
      await c.read(pushRegistrationProvider).forget();
      expect(repo.removed, isEmpty);
    });
  });

  group('tapping a push', () {
    Future<void> pumpApp(WidgetTester t, _FakePush service) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      push = service;
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/:a',
            builder: (_, _) => const SizedBox(),
            routes: [GoRoute(path: ':b', builder: (_, _) => const SizedBox())],
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            sessionProvider.overrideWith(() => FakeSession(guestUser)),
            notificationRepositoryProvider.overrideWithValue(repo),
            pushServiceProvider.overrideWithValue(push),
            routerProvider.overrideWithValue(router),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(pushCoordinatorProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    // A pushed page sits on top of the current one: read the topmost match.
    String where() => router.routerDelegate.currentConfiguration.last.matchedLocation;

    testWidgets('opens the screen for that kind of notification', (t) async {
      await pumpApp(t, _FakePush());
      push.openedController.add(payload('COMPLAINT_RESOLVED', {'complaintId': 'c9', 'audience': 'TENANT'}));
      await t.pumpAndSettle();
      expect(where(), '/account/complaints/c9');
    });

    testWidgets('an owner\'s rent push opens the owner rent screen; a tenant\'s opens My stay', (t) async {
      await pumpApp(t, _FakePush());
      push.openedController.add(payload('RENT_OVERDUE', {'audience': 'OWNER'}));
      await t.pumpAndSettle();
      expect(where(), '/host/rent');
      push.openedController.add(payload('RENT_OVERDUE', {'audience': 'TENANT'}));
      await t.pumpAndSettle();
      expect(where(), '/account/stay');
    });

    testWidgets('the push that launched the app from closed is opened too', (t) async {
      await pumpApp(t, _FakePush()..launch = payload('DEPOSIT_SETTLED', {'audience': 'TENANT'}));
      expect(where(), '/account/stay');
    });

    testWidgets('an unknown kind of push opens nothing and does not crash', (t) async {
      await pumpApp(t, _FakePush());
      push.openedController.add(payload('SOMETHING_NEW'));
      await t.pumpAndSettle();
      expect(where(), '/');
    });
  });
}
