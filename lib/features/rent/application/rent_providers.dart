import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../domain/rent_models.dart';

/// The signed-in tenant's own invoices, newest due date first.
final myInvoicesProvider = AsyncNotifierProvider<MyInvoicesNotifier, PageState<RentInvoice>>(MyInvoicesNotifier.new);

class MyInvoicesNotifier extends PagedNotifier<RentInvoice> {
  @override
  Future<PageState<RentInvoice>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<RentInvoice>> fetch(String? cursor) => ref.read(rentRepositoryProvider).myInvoices(cursor: cursor);
}

/// The owner's view: which invoices to show.
enum HostRentTab {
  overdue('Overdue'),
  due('Due'),
  paid('Paid');

  const HostRentTab(this.label);
  final String label;
}

final hostInvoicesProvider = AsyncNotifierProvider.family<HostInvoicesNotifier, PageState<RentInvoice>, HostRentTab>(HostInvoicesNotifier.new);

class HostInvoicesNotifier extends PagedNotifier<RentInvoice> {
  HostInvoicesNotifier(this.tab);
  final HostRentTab tab;

  @override
  Future<PageState<RentInvoice>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<RentInvoice>> fetch(String? cursor) {
    final repo = ref.read(rentRepositoryProvider);
    return switch (tab) {
      HostRentTab.overdue => repo.hostInvoices(overdue: true, cursor: cursor),
      HostRentTab.due => repo.hostInvoices(status: 'DUE', cursor: cursor),
      HostRentTab.paid => repo.hostInvoices(status: 'PAID', cursor: cursor),
    };
  }
}

/// Billed, collected and owed for the current month.
final rentRollProvider = FutureProvider.autoDispose<RentRoll>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(rentRepositoryProvider).roll();
});
