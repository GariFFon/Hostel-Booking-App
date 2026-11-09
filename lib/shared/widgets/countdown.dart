import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shared 1 Hz clock for every countdown on screen (it only runs while something watches it).
final secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) => Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()));

/// Rebuilds once a second with the time left until [until]; fires [onElapsed] once when it reaches zero.
class Countdown extends ConsumerStatefulWidget {
  const Countdown({super.key, required this.until, required this.builder, this.onElapsed});

  final DateTime until;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onElapsed;

  @override
  ConsumerState<Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<Countdown> {
  bool _fired = false;

  @override
  void didUpdateWidget(covariant Countdown old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _fired = false;
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickProvider).value ?? DateTime.now();
    final remaining = widget.until.difference(now);
    if (remaining.isNegative || remaining == Duration.zero) {
      if (!_fired && widget.onElapsed != null) {
        _fired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onElapsed!();
        });
      }
      return widget.builder(context, Duration.zero);
    }
    return widget.builder(context, remaining);
  }
}
