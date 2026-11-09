import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/application/session.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/bookings/data/booking_repository.dart';
import '../features/host/data/host_repository.dart';
import '../features/hostels/data/hostel_repository.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/reviews/data/review_repository.dart';
import '../features/wishlist/data/wishlist_repository.dart';
import 'config/env.dart';
import 'network/api_client.dart';
import 'network/token_store.dart';

/// Riverpod 3 retries a failed provider up to 10 times with back-off (about 40 s) before the error reaches the UI.
/// Here every error state already has an instant "Try again" (and pull-to-refresh), so failures surface at once.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Overridden in `main` once the flavour and preferences are known.
final envProvider = Provider<Env>((ref) => throw UnimplementedError('envProvider must be overridden'));
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'));

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(envProvider).apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
    onSignedOut: () => ref.read(sessionProvider.notifier).expired(),
    onSessionUser: (json) => ref.read(sessionProvider.notifier).refreshedUser(json),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
final hostelRepositoryProvider = Provider<HostelRepository>((ref) => HostelRepository(ref.watch(apiClientProvider)));
final bookingRepositoryProvider = Provider<BookingRepository>((ref) => BookingRepository(ref.watch(apiClientProvider)));
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(apiClientProvider)));
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) => WishlistRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(apiClientProvider)));
final hostRepositoryProvider = Provider<HostRepository>((ref) => HostRepository(ref.watch(apiClientProvider)));

/// Light / dark / follow the system. Stored in plain preferences (not sensitive).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}
