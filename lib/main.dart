import 'package:flutter/foundation.dart';

import 'bootstrap.dart';
import 'core/config/env.dart';

/// The only entry point. Debug and profile runs (`flutter run`, VS Code "Run") use the dev settings: the deployed API by default, API logging
/// on. A release build uses the production settings, which require `--dart-define=API_BASE_URL=https://<host>/api/v1`.
Future<void> main() => bootstrap(kReleaseMode ? Env.prod() : Env.dev());
