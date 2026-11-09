import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes each `takeScreenshot(name)` to `$SHOTS_DIR/<name>.png` (default `build/shots`).
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')..createSync(recursive: true);
        File('${dir.path}/$name.png').writeAsBytesSync(bytes);
        return true;
      },
    );
