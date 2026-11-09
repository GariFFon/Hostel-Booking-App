import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/network/token_store.dart';
import 'core/providers.dart';

/// Shared start-up for every flavour. Never logs request bodies, tokens or personal data.
///
/// Everything runs inside one guarded zone (binding initialisation included, so `runApp` shares its zone), and a failure while
/// clearing a stale keychain must not stop the app from launching.
Future<void> bootstrap(Env env) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('en_IN');
      Intl.defaultLocale = 'en_IN';

      final prefs = await SharedPreferences.getInstance();
      final tokens = SecureTokenStore();

      // The iOS keychain survives an uninstall; a fresh install must not silently resume an old session.
      if (!(prefs.getBool('installed') ?? false)) {
        try {
          await tokens.clear();
        } catch (_) {
          // A locked or corrupted keychain: start signed out anyway; the next sign-in rewrites it.
        }
        await prefs.setBool('installed', true);
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        // A crash-reporting hook would go here; intentionally nothing is sent today.
      };

      runApp(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: [envProvider.overrideWithValue(env), sharedPrefsProvider.overrideWithValue(prefs), tokenStoreProvider.overrideWithValue(tokens)],
          child: const HostelApp(),
        ),
      );
    },
    (error, stack) {
      if (kDebugMode) debugPrint('Unhandled: $error\n$stack');
    },
  );
}
