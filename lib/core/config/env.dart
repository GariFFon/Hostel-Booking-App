import 'package:flutter/foundation.dart';

/// Build flavour. `dev` talks to a local backend by default; `prod` needs `--dart-define=API_BASE_URL=...`.
enum AppFlavor { dev, prod }

@immutable
class Env {
  const Env({required this.flavor, required this.apiBaseUrl, this.osmUserAgent = 'com.hostelbooking.hostel_booking_app'});

  final AppFlavor flavor;

  /// Includes the version prefix, e.g. `http://10.0.2.2:4000/api/v1` (no trailing slash).
  final String apiBaseUrl;

  /// OpenStreetMap's tile policy requires an identifiable app id.
  final String osmUserAgent;

  bool get isDev => flavor == AppFlavor.dev;

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Dev defaults: the Android emulator reaches the host machine at 10.0.2.2, iOS simulators share localhost.
  factory Env.dev() {
    final fallback = defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:4000/api/v1' : 'http://localhost:4000/api/v1';
    return Env(flavor: AppFlavor.dev, apiBaseUrl: _normalise(_override.isEmpty ? fallback : _override));
  }

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
