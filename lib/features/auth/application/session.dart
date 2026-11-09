import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/app_user.dart';

/// Who is signed in. `AsyncData(null)` is "signed out"; an error means the stored session could not be checked (usually offline).
final sessionProvider = AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);

/// Just the id: providers that only depend on *who* is signed in rebuild on sign-in/out, not on every profile edit.
final userIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.value?.id)));

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(sessionProvider).value);

class SessionController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final tokens = ref.read(tokenStoreProvider);
    if (await tokens.read() == null) return null;
    try {
      return await ref.read(authRepositoryProvider).me();
    } on ApiException catch (e) {
      if (e.isUnauthenticated) {
        await tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final user = await ref.read(authRepositoryProvider).login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> signUp({required String fullName, required String email, required String password, String? phone}) async {
    final user = await ref.read(authRepositoryProvider).register(fullName: fullName, email: email, password: password, phone: phone);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  /// The refresh token was rejected (or the session was revoked elsewhere): back to signed-out without a network call.
  void expired() => state = const AsyncData(null);

  void setUser(AppUser user) => state = AsyncData(user);

  /// The refresh endpoint returns the user; keep roles and verification fresh without another request.
  void refreshedUser(Map<String, dynamic> json) {
    if (state.value == null) return;
    state = AsyncData(AppUser.fromJson(json));
  }

  Future<void> reload() async => state = AsyncData(await ref.read(authRepositoryProvider).me());

  Future<void> updateProfile({String? fullName, String? phone}) async {
    final user = await ref.read(authRepositoryProvider).updateProfile(fullName: fullName, phone: phone);
    state = AsyncData(user);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = await ref.read(authRepositoryProvider).changePassword(currentPassword: currentPassword, newPassword: newPassword);
    state = AsyncData(user);
  }

  Future<void> becomeHost() async {
    final user = await ref.read(authRepositoryProvider).becomeOwner();
    state = AsyncData(user);
  }
}
