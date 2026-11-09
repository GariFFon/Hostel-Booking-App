import 'bootstrap.dart';
import 'core/config/env.dart';

/// Default entry point (`flutter run`): the dev flavour. Use `lib/main_prod.dart` for production builds.
Future<void> main() => bootstrap(Env.dev());
