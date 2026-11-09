import 'bootstrap.dart';
import 'core/config/env.dart';

/// Dev flavour: talks to a local backend (10.0.2.2:4000 on the Android emulator, localhost on iOS) unless
/// `--dart-define=API_BASE_URL=...` says otherwise.
Future<void> main() => bootstrap(Env.dev());
