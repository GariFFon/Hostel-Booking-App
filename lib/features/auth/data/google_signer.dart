import 'package:google_sign_in/google_sign_in.dart';

/// Gets a Google ID token for the person. A seam so the screens can be tested without the platform plugin.
abstract interface class GoogleSigner {
  /// The ID token, or `null` when the person closed the Google sheet (not an error).
  Future<String?> idToken();
}

class PlatformGoogleSigner implements GoogleSigner {
  PlatformGoogleSigner({required this.serverClientId, required this.iosClientId});

  final String serverClientId;
  final String iosClientId;
  Future<void>? _initialised;

  Future<void> _init() => _initialised ??= GoogleSignIn.instance.initialize(clientId: iosClientId, serverClientId: serverClientId);

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
      rethrow;
    }
  }
}
