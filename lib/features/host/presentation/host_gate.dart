import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';

/// Host screens are for accounts with the OWNER role. A deep link or a stale notification can still land a guest here,
/// so say what is going on instead of showing an empty or failing screen. (The server enforces this too.)
class HostGate extends ConsumerWidget {
  const HostGate({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user != null && user.isOwner) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.home_work_outlined,
        title: 'Hosting is not set up',
        message: 'Turn on hosting from your account to list stays and manage bookings.',
        actionLabel: 'Go to account',
        onAction: () => context.go(Routes.account),
      ),
    );
  }
}
