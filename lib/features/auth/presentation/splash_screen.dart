import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/states.dart';
import '../application/session.dart';

/// Shown while the stored session is being checked. If the check fails (offline), offers a retry instead of a blank screen.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: session.hasError && !session.isLoading
            ? ErrorState(error: session.error!, onRetry: () => ref.invalidate(sessionProvider))
            : const Center(child: BrandMark(size: 72)),
      ),
    );
  }
}
