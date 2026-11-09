import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/network/token_store.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<AppUser> _storeSession(Envelope e) async {
    final result = AuthResult.fromJson(asMap(e.data));
    await _tokens.write(TokenPair(access: result.accessToken, refresh: result.refreshToken));
    return result.user;
  }

  Future<AppUser> login({required String email, required String password}) async =>
      _storeSession(await _api.post('/auth/login', body: {'email': email.trim(), 'password': password}, auth: false));

  Future<AppUser> register({required String fullName, required String email, required String password, String? phone, bool asOwner = false}) async =>
      _storeSession(await _api.post(
        '/auth/register',
        body: {
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (asOwner) 'role': 'OWNER',
        },
        auth: false,
      ));

  Future<AppUser> me() => _api.getOne('/me', AppUser.fromJson);

  /// Revokes the session family on the server (best effort) and forgets the tokens locally.
  Future<void> logout() async {
    final t = await _tokens.read();
    try {
      if (t != null) await _api.post('/auth/logout', body: {'refreshToken': t.refresh}, auth: false);
    } catch (_) {
      // Offline sign-out must still work: the local session is wiped below either way.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> forgotPassword(String email) => _api.post('/auth/forgot-password', body: {'email': email.trim()}, auth: false);

  Future<void> resetPassword({required String token, required String password}) =>
      _api.post('/auth/reset-password', body: {'token': token.trim(), 'password': password}, auth: false);

  Future<void> resendVerification(String email) => _api.post('/auth/resend-verification', body: {'email': email.trim()}, auth: false);

  Future<void> verifyEmail(String token) => _api.post('/auth/verify-email', body: {'token': token.trim()}, auth: false);

  Future<AppUser> updateProfile({String? fullName, String? phone}) async => AppUser.fromJson(asMap((await _api.patch('/me', body: {
        'fullName': ?fullName,
        'phone': ?phone,
      })).data));

  /// Signs out other devices and hands back a fresh session for this one.
  Future<AppUser> changePassword({required String currentPassword, required String newPassword}) async =>
      _storeSession(await _api.post('/me/password', body: {'currentPassword': currentPassword, 'newPassword': newPassword}));

  /// Adds the OWNER role; the access token must be refreshed afterwards to carry it.
  Future<AppUser> becomeOwner() async {
    await _api.post('/me/become-owner');
    await _api.refreshSession();
    return me();
  }

  Future<void> registerDevice({required String platform, required String pushToken}) =>
      _api.post('/me/devices', body: {'platform': platform, 'pushToken': pushToken});
}
