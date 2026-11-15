import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'complaint_widgets.dart';

/// Maintenance people see the jobs assigned to them. Joining a team happens from the invitation email (on the website);
/// anyone else who lands here is told what this area is, instead of seeing an empty or failing screen. (The server enforces this too.)
class StaffGate extends ConsumerWidget {
  const StaffGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user != null && user.isStaff) return child;
    return Scaffold(
      appBar: AppBar(title: const Text('My jobs')),
      body: EmptyState(
        icon: Icons.handyman_outlined,
        title: 'This area is for maintenance staff',
        message: 'Ask a property owner to invite you. When the invitation email arrives, paste its link here to join.',
        actionLabel: 'I have an invitation',
        onAction: () => context.push(Routes.joinTeam),
      ),
    );
  }
}

class StaffJobsScreen extends ConsumerWidget {
  const StaffJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StaffGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('My jobs')),
        body: PagedScroll<ComplaintSummary>(
          value: ref.watch(staffJobsProvider),
          onLoadMore: () => ref.read(staffJobsProvider.notifier).loadMore(),
          onRefresh: () async {
            ref.invalidate(staffJobsProvider);
            ref.invalidate(staffMeProvider);
            await ref.read(staffJobsProvider.future);
          },
          header: const _Profile(),
          empty: const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No jobs right now',
            message: 'New jobs for your properties show up here, and you are notified when one is assigned to you.',
          ),
          itemBuilder: (context, c, _) => ComplaintCard(complaint: c, forStaff: true, onTap: () => context.push('${Routes.staffJobs}/jobs/${c.id}')),
        ),
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(staffMeProvider).value;
    if (me == null) return const SizedBox.shrink();
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tradeLabel(me.trade)}${me.employer != null ? ' for ${me.employer}' : ' · platform vendor'}', style: t.titleMedium),
          Text(me.hostels.isEmpty ? 'Not added to a property yet' : me.hostels.map((h) => h.name).join(', '), style: t.bodySmall),
          if (!me.active) ...[const SizedBox(height: 8), const StatusChip('Paused: you will not get new jobs', tone: Tone.warning)],
        ],
      ),
    );
  }
}
