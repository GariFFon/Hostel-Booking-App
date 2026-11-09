import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../data/review_repository.dart';
import '../domain/review_models.dart';

@immutable
class ReviewsQuery {
  const ReviewsQuery(this.slug, {this.sort = ReviewSort.recent, this.rating});
  final String slug;
  final ReviewSort sort;
  final int? rating;

  @override
  bool operator ==(Object other) => other is ReviewsQuery && other.slug == slug && other.sort == sort && other.rating == rating;

  @override
  int get hashCode => Object.hash(slug, sort, rating);
}

final hostelReviewsProvider =
    AsyncNotifierProvider.autoDispose.family<HostelReviewsNotifier, PageState<Review>, ReviewsQuery>(HostelReviewsNotifier.new);

class HostelReviewsNotifier extends PagedNotifier<Review> {
  HostelReviewsNotifier(this.query);
  final ReviewsQuery query;

  @override
  Future<Paged<Review>> fetch(String? cursor) =>
      ref.read(reviewRepositoryProvider).forHostel(query.slug, sort: query.sort, rating: query.rating, cursor: cursor);
}

final reviewSummaryProvider =
    FutureProvider.autoDispose.family<ReviewSummary, String>((ref, slug) => ref.watch(reviewRepositoryProvider).summary(slug));

final myReviewsProvider = AsyncNotifierProvider<MyReviewsNotifier, PageState<Review>>(MyReviewsNotifier.new);

class MyReviewsNotifier extends PagedNotifier<Review> {
  @override
  Future<PageState<Review>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<Review>> fetch(String? cursor) => ref.read(reviewRepositoryProvider).mine(cursor: cursor);
}
