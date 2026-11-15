import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/states.dart';
import '../../host/presentation/host_gate.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'complaint_widgets.dart';

/// The owner's complaint inbox. Staff of the right trade get new complaints automatically; what no one could take waits under "Needs assigning".
class HostComplaintsScreen extends ConsumerWidget {
  const HostComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HostGate(
      title: 'Complaints',
      child: DefaultTabController(
        length: HostComplaintTab.values.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Complaints'),
            actions: [
              IconButton(tooltip: 'Maintenance staff', icon: const Icon(Icons.engineering_outlined), onPressed: () => context.push(Routes.hostStaff)),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final t in HostComplaintTab.values) Tab(text: t.label)],
            ),
          ),
          body: TabBarView(children: [for (final t in HostComplaintTab.values) _Tab(tab: t)]),
        ),
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  const _Tab({required this.tab});
  final HostComplaintTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = hostComplaintsProvider(tab);
    return PagedScroll<ComplaintSummary>(
      value: ref.watch(provider),
      onLoadMore: () => ref.read(provider.notifier).loadMore(),
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      empty: EmptyState(
        icon: Icons.build_circle_outlined,
        title: switch (tab) {
          HostComplaintTab.needsAssigning => 'Nothing waiting for you',
          HostComplaintTab.overdue => 'Nothing overdue',
          _ => 'No complaints here',
        },
        message: tab == HostComplaintTab.needsAssigning
            ? 'Complaints that no staff member could take show up here.'
            : 'Complaints appear here as tenants report them.',
      ),
      itemBuilder: (context, c, _) => ComplaintCard(complaint: c, owner: true, onTap: () => context.push('${Routes.hostComplaints}/${c.id}')),
    );
  }
}
