import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/states.dart';
import '../application/review_providers.dart';
import '../data/review_repository.dart';
import 'review_widgets.dart';

/// Every review of one property: the summary, then the list with a sort and a star filter.
class HostelReviewsScreen extends ConsumerStatefulWidget {
  const HostelReviewsScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<HostelReviewsScreen> createState() => _HostelReviewsScreenState();
}

class _HostelReviewsScreenState extends ConsumerState<HostelReviewsScreen> {
  ReviewSort _sort = ReviewSort.recent;
  int? _rating;

  ReviewsQuery get _query => ReviewsQuery(widget.slug, sort: _sort, rating: _rating);

  @override
  Widget build(BuildContext context) {
    final provider = hostelReviewsProvider(_query);
    final summary = ref.watch(reviewSummaryProvider(widget.slug));

    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: PagedScroll(
        value: ref.watch(provider),
        separator: 12,
        onLoadMore: () => ref.read(provider.notifier).loadMore(),
        onRefresh: () async {
          ref.invalidate(reviewSummaryProvider(widget.slug));
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summary.when(
                loading: () => const Skeleton(child: SkeletonBox(height: 110, radius: 16)),
                error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(reviewSummaryProvider(widget.slug))),
                data: (s) => ReviewSummaryView(summary: s),
              ),
              const SizedBox(height: 16),
              _Filters(sort: _sort, rating: _rating, onSort: (s) => setState(() => _sort = s), onRating: (r) => setState(() => _rating = r)),
            ],
          ),
        ),
        empty: EmptyState(
          icon: Icons.star_outline_rounded,
          title: _rating == null ? 'No reviews yet' : 'No $_rating-star reviews',
          message: _rating == null ? 'Guests can review after they have stayed.' : 'Try another rating, or show all reviews.',
          actionLabel: _rating == null ? null : 'Show all',
          onAction: () => setState(() => _rating = null),
        ),
        itemBuilder: (context, r, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ReviewTile(review: r),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.sort, required this.rating, required this.onSort, required this.onRating});
  final ReviewSort sort;
  final int? rating;
  final ValueChanged<ReviewSort> onSort;
  final ValueChanged<int?> onRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: 'Filter by stars',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(label: const Text('All'), selected: rating == null, onSelected: (_) => onRating(null)),
                for (var i = 5; i >= 1; i--) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text('$i ★'), selected: rating == i, onSelected: (_) => onRating(rating == i ? null : i)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<ReviewSort>(
            tooltip: 'Sort reviews',
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [for (final s in ReviewSort.values) PopupMenuItem(value: s, child: Text(s.label))],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text(sort.label, style: Theme.of(context).textTheme.labelLarge),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
