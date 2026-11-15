import 'package:flutter/foundation.dart';

/// Build flavour. `dev` talks to the cloud API by default; `prod` needs `--dart-define=API_BASE_URL=...`.
enum AppFlavor { dev, prod }

@immutable
class Env {
  const Env({
    required this.flavor,
    required this.apiBaseUrl,
    this.osmUserAgent = 'com.hostelbooking.hostel_booking_app',
    this.googleServerClientId = _defaultGoogleWebClientId,
    this.googleIosClientId = _defaultGoogleIosClientId,
  });

  /// Google OAuth client ids. They are public identifiers (not secrets); the backend accepts ID tokens whose audience is one of its
  /// `GOOGLE_CLIENT_IDS`. The *web* id is the `serverClientId`, so every platform gets a token with the same audience.
  static const String _defaultGoogleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '72982205614-2jcg60qd21iedr2h7k2qee0dpa9f1r4u.apps.googleusercontent.com',
  );
  static const String _defaultGoogleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '72982205614-8iteashrgqs7p5e3u3b2844mkl27npoc.apps.googleusercontent.com',
  );
  final String googleServerClientId;
  final String googleIosClientId;

  final AppFlavor flavor;

  /// Includes the version prefix, e.g. `http://10.0.2.2:4000/api/v1` (no trailing slash).
  final String apiBaseUrl;

  /// OpenStreetMap's tile policy requires an identifiable app id.
  final String osmUserAgent;

  bool get isDev => flavor == AppFlavor.dev;

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Debug/profile runs talk to the deployed (Render) API by default, so "Run" works from any entry point without extra flags.
  /// For a backend on this machine pass `--dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` (Android emulator) or
  /// `http://localhost:4000/api/v1` (iOS simulator). Note the free Render instance sleeps: the first request can take ~1 minute.
  static const String cloudApiBaseUrl = 'https://hostel-booking-api-u2po.onrender.com/api/v1';

  factory Env.dev() => Env(flavor: AppFlavor.dev, apiBaseUrl: _normalise(_override.isEmpty ? cloudApiBaseUrl : _override));

  factory Env.prod() {
    if (_override.isEmpty) {
      throw StateError('Production builds need --dart-define=API_BASE_URL=https://<host>/api/v1');
    }
    if (!_override.startsWith('https://')) {
      throw StateError('Production API_BASE_URL must use https');
    }
    return Env(flavor: AppFlavor.prod, apiBaseUrl: _normalise(_override));
  }

  static String _normalise(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
