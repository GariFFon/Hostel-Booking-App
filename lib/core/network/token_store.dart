import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// Where the session lives. Access and refresh tokens never touch plain preferences or logs.
abstract interface class TokenStore {
  Future<TokenPair?> read();
  Future<void> write(TokenPair tokens);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed storage (Android). Reads are cached in memory because the interceptor asks on every request.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Never migrate the session to a new device through backups.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  static const _accessKey = 'hb.access';
  static const _refreshKey = 'hb.refresh';

  final FlutterSecureStorage _storage;
  TokenPair? _cache;
  bool _loaded = false;

  @override
  Future<TokenPair?> read() async {
    if (_loaded) return _cache;
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    _cache = access != null && refresh != null ? TokenPair(access: access, refresh: refresh) : null;
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> write(TokenPair tokens) async {
    _cache = tokens;
    _loaded = true;
    await _storage.write(key: _refreshKey, value: tokens.refresh); // refresh first: it is the one that must survive a crash
    await _storage.write(key: _accessKey, value: tokens.access);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);
  TokenPair? _tokens;

  @override
  Future<TokenPair?> read() async => _tokens;

  @override
  Future<void> write(TokenPair tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
