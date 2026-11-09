import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../../bookings/domain/booking_models.dart';
import '../../reviews/domain/review_models.dart';
import '../domain/host_models.dart';

enum HostBookingTab {
  requests('Requests'),
  upcoming('Upcoming'),
  past('Past');

  const HostBookingTab(this.label);
  final String label;
}

final hostBookingsProvider =
    AsyncNotifierProvider.family<HostBookingsNotifier, PageState<BookingSummary>, HostBookingTab>(HostBookingsNotifier.new);

class HostBookingsNotifier extends PagedNotifier<BookingSummary> {
  HostBookingsNotifier(this.tab);
  final HostBookingTab tab;

  @override
  Future<PageState<BookingSummary>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<BookingSummary>> fetch(String? cursor) {
    final repo = ref.read(hostRepositoryProvider);
    return switch (tab) {
      HostBookingTab.requests => repo.bookings(status: 'PENDING_APPROVAL', cursor: cursor),
      HostBookingTab.upcoming => repo.bookings(when: 'upcoming', cursor: cursor),
      HostBookingTab.past => repo.bookings(when: 'past', cursor: cursor),
    };
  }
}

final hostBookingDetailProvider =
    FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(hostRepositoryProvider).booking(id));

final earningsProvider = FutureProvider.autoDispose<Earnings>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(hostRepositoryProvider).earnings();
});

final hostHostelsProvider = AsyncNotifierProvider<HostHostelsNotifier, PageState<OwnerHostel>>(HostHostelsNotifier.new);

class HostHostelsNotifier extends PagedNotifier<OwnerHostel> {
  @override
  Future<PageState<OwnerHostel>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<OwnerHostel>> fetch(String? cursor) => ref.read(hostRepositoryProvider).hostels(cursor: cursor);
}

/// `null` = all, `false` = still needs a reply.
final hostReviewsProvider = AsyncNotifierProvider.family<HostReviewsNotifier, PageState<Review>, bool?>(HostReviewsNotifier.new);

class HostReviewsNotifier extends PagedNotifier<Review> {
  HostReviewsNotifier(this.replied);
  final bool? replied;

  @override
  Future<PageState<Review>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<Review>> fetch(String? cursor) => ref.read(hostRepositoryProvider).reviews(replied: replied, cursor: cursor);
}
