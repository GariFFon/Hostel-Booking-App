import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// What a push carries: enough to open the right screen. `data` holds the same deep-link hints as an in-app notification.
class PushPayload {
  const PushPayload({required this.type, required this.data, this.title = '', this.body = ''});
  final String type;
  final Map<String, String> data;
  final String title;
  final String body;

  String? get notificationId => data['notificationId'];
}

/// The phone side of push, behind an interface so the app logic can be tested without Firebase.
abstract class PushService {
  /// False when push cannot work here (no Firebase config, an unsupported platform, or the user said no).
  bool get available;

  /// Asks for permission (Android 13+ shows a prompt) and returns the device token, or null when not allowed or unavailable.
  Future<String?> start();

  /// A new token to register (tokens rotate).
  Stream<String> get tokenChanges;

  /// A push arrived while the app was open (the system shows nothing in that case).
  Stream<PushPayload> get foreground;

  /// The user tapped a push while the app was in the background.
  Stream<PushPayload> get opened;

  /// The push that launched the app from a closed state, if any (read once).
  Future<PushPayload?> launchedBy();

  String get platform;
}

/// Used in tests and wherever Firebase is not set up: does nothing.
class NoopPushService implements PushService {
  const NoopPushService();
  @override
  bool get available => false;
  @override
  Future<String?> start() async => null;
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<PushPayload> get foreground => const Stream.empty();
  @override
  Stream<PushPayload> get opened => const Stream.empty();
  @override
  Future<PushPayload?> launchedBy() async => null;
  @override
  String get platform => 'ANDROID';
}

PushPayload? _payload(RemoteMessage m) {
  final data = {for (final e in m.data.entries) e.key: '${e.value}'};
  final type = data['type'];
  if (type == null) return null;
  return PushPayload(type: type, data: data, title: m.notification?.title ?? '', body: m.notification?.body ?? '');
}

/// Firebase Cloud Messaging. Everything is guarded: a missing `google-services.json`, a phone without Google services, or a refused
/// permission leaves the app working without push, never broken.
class FirebasePushService implements PushService {
  FirebasePushService._(this._ok);

  final bool _ok;

  /// Initialises Firebase once. Returns a service that is inert when that fails.
  static Future<PushService> create() async {
    try {
      await Firebase.initializeApp();
      return FirebasePushService._(true);
    } catch (e) {
      if (kDebugMode) debugPrint('Push disabled (Firebase did not start): $e');
      return const NoopPushService();
    }
  }

  @override
  bool get available => _ok;

  @override
  String get platform => Platform.isIOS ? 'IOS' : 'ANDROID';

  @override
  Future<String?> start() async {
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      // The classic FCM registration token (what the server's HTTP v1 send expects). The package's newer register()/onRegistered API
      // yields Firebase Installation IDs for a different, direct-send mode.
      // ignore: deprecated_member_use
      return await m.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('Push start failed: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenChanges => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushPayload> get foreground => FirebaseMessaging.onMessage.map(_payload).where((p) => p != null).cast<PushPayload>();

  @override
  Stream<PushPayload> get opened => FirebaseMessaging.onMessageOpenedApp.map(_payload).where((p) => p != null).cast<PushPayload>();

  @override
  Future<PushPayload?> launchedBy() async {
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _payload(m);
    } catch (_) {
      return null;
    }
  }
}
