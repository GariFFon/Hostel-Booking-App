import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../data/booking_repository.dart';
import '../domain/booking_models.dart';
import '../domain/payment_models.dart';
import '../domain/quote_models.dart';

/// Trips tabs: `upcoming`, `past`, `all`.
final bookingListProvider = AsyncNotifierProvider.family<BookingListNotifier, PageState<BookingSummary>, String>(BookingListNotifier.new);

class BookingListNotifier extends PagedNotifier<BookingSummary> {
  BookingListNotifier(this.when);
  final String when;

  @override
  Future<PageState<BookingSummary>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<BookingSummary>> fetch(String? cursor) => ref.read(bookingRepositoryProvider).list(when: when, cursor: cursor);
}

final bookingDetailProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(bookingRepositoryProvider).detail(id));

final cancellationPreviewProvider = FutureProvider.autoDispose.family<CancellationPreview, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).cancellationPreview(id),
);

@immutable
class QuoteArgs {
  const QuoteArgs({
    required this.hostelId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.items,
    this.couponCode,
  });
  final String hostelId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final List<RoomSelection> items;
  final String? couponCode;

  @override
  bool operator ==(Object other) =>
      other is QuoteArgs &&
      other.hostelId == hostelId &&
      other.checkIn == checkIn &&
      other.checkOut == checkOut &&
      other.guests == guests &&
      other.couponCode == couponCode &&
      listEquals(other.items.map((i) => '${i.roomTypeId}:${i.units}').toList(), items.map((i) => '${i.roomTypeId}:${i.units}').toList());

  @override
  int get hashCode => Object.hash(hostelId, checkIn, checkOut, guests, couponCode, Object.hashAll(items.map((i) => '${i.roomTypeId}:${i.units}')));
}

/// Read-only price quote (holds nothing). Re-fetched whenever the selection, dates or coupon change.
final quoteProvider = FutureProvider.autoDispose.family<Quote, QuoteArgs>((ref, a) {
  return ref
      .watch(bookingRepositoryProvider)
      .quote(hostelId: a.hostelId, checkIn: a.checkIn, checkOut: a.checkOut, guests: a.guests, items: a.items, couponCode: a.couponCode);
});
