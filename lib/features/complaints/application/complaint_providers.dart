import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../domain/complaint_models.dart';

/// The signed-in tenant's own complaints.
final myComplaintsProvider = AsyncNotifierProvider<MyComplaintsNotifier, PageState<ComplaintSummary>>(MyComplaintsNotifier.new);

class MyComplaintsNotifier extends PagedNotifier<ComplaintSummary> {
  @override
  Future<PageState<ComplaintSummary>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<ComplaintSummary>> fetch(String? cursor) => ref.read(complaintRepositoryProvider).mine(cursor: cursor);
}

/// A maintenance person's open jobs.
final staffJobsProvider = AsyncNotifierProvider<StaffJobsNotifier, PageState<ComplaintSummary>>(StaffJobsNotifier.new);

class StaffJobsNotifier extends PagedNotifier<ComplaintSummary> {
  @override
  Future<PageState<ComplaintSummary>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<ComplaintSummary>> fetch(String? cursor) => ref.read(complaintRepositoryProvider).jobs(cursor: cursor);
}

final staffMeProvider = FutureProvider.autoDispose<StaffMe>((ref) => ref.watch(complaintRepositoryProvider).staffMe());

/// One complaint with its comments, photos and timeline.
final complaintDetailProvider = FutureProvider.autoDispose.family<ComplaintDetail, String>(
  (ref, id) => ref.watch(complaintRepositoryProvider).detail(id),
);

/// The owner's complaint inbox, one list per tab.
enum HostComplaintTab {
  needsAssigning('Needs assigning'),
  overdue('Overdue'),
  inProgress('In progress'),
  resolved('Resolved'),
  all('All');

  const HostComplaintTab(this.label);
  final String label;
}

final hostComplaintsProvider = AsyncNotifierProvider.family<HostComplaintsNotifier, PageState<ComplaintSummary>, HostComplaintTab>(
  HostComplaintsNotifier.new,
);

class HostComplaintsNotifier extends PagedNotifier<ComplaintSummary> {
  HostComplaintsNotifier(this.tab);
  final HostComplaintTab tab;

  @override
  Future<PageState<ComplaintSummary>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<ComplaintSummary>> fetch(String? cursor) {
    final repo = ref.read(complaintRepositoryProvider);
    return switch (tab) {
      HostComplaintTab.needsAssigning => repo.ownerList(unassigned: true, cursor: cursor),
      HostComplaintTab.overdue => repo.ownerList(overdue: true, cursor: cursor),
      HostComplaintTab.resolved => repo.ownerList(status: 'RESOLVED', cursor: cursor),
      // "In progress" is every complaint that is with someone: the server has no single filter for it, so it is narrowed here.
      HostComplaintTab.inProgress =>
        repo
            .ownerList(cursor: cursor)
            .then(
              (p) => Paged<ComplaintSummary>(
                items: p.items
                    .where(
                      (c) => const {
                        ComplaintStatus.assigned,
                        ComplaintStatus.inProgress,
                        ComplaintStatus.onHold,
                        ComplaintStatus.reopened,
                        ComplaintStatus.acknowledged,
                      }.contains(c.status),
                    )
                    .toList(),
                nextCursor: p.nextCursor,
                total: p.total,
              ),
            ),
      HostComplaintTab.all => repo.ownerList(cursor: cursor),
    };
  }
}

/// The owner's maintenance team and pending invitations.
final ownerTeamProvider = FutureProvider.autoDispose<OwnerTeam>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(complaintRepositoryProvider).team();
});

final vendorsProvider = FutureProvider.autoDispose<List<VendorItem>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(complaintRepositoryProvider).vendors();
});
