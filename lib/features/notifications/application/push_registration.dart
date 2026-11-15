import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/push_service.dart';

/// Which push implementation the app uses. Defaults to "none"; `bootstrap` swaps in Firebase, tests swap in a fake.
final pushServiceProvider = Provider<PushService>((ref) => const NoopPushService());

/// Tells the server which phone belongs to the signed-in person, and forgets it on sign-out so the next person on this phone
/// (or nobody) does not receive their notifications. Both calls are best effort: push is never worth failing a sign-in or sign-out for.
final pushRegistrationProvider = Provider<PushRegistration>((ref) => PushRegistration(ref));

class PushRegistration {
  PushRegistration(this._ref);
  final Ref _ref;

  static const _key = 'pushDeviceId';

  Future<void> register(String token) async {
    try {
      final id = await _ref.read(notificationRepositoryProvider).registerDevice(platform: _ref.read(pushServiceProvider).platform, pushToken: token);
      await _ref.read(sharedPrefsProvider).setString(_key, id);
    } catch (_) {
      // Offline or refused: it is registered again at the next start-up.
    }
  }

  /// Call while still signed in (the server needs the session to remove the device).
  Future<void> forget() async {
    final prefs = _ref.read(sharedPrefsProvider);
    final id = prefs.getString(_key);
    if (id == null) return;
    try {
      await _ref.read(notificationRepositoryProvider).removeDevice(id);
    } catch (_) {
      // Already gone, or offline: nothing more to do.
    }
    await prefs.remove(_key);
  }
}
