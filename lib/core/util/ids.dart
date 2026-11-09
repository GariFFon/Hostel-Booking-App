import 'dart:math';

final Random _rng = Random.secure();

/// Random 32-hex-character id. Used for `Idempotency-Key` (backend wants 8-80 chars): one per user action, reused on retries.
String newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
