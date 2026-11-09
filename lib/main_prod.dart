import 'bootstrap.dart';
import 'core/config/env.dart';

/// Production flavour: requires `--dart-define=API_BASE_URL=https://<host>/api/v1` (https only).
Future<void> main() => bootstrap(Env.prod());
