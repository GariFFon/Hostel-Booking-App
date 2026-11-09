import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/states.dart';
import '../application/review_providers.dart';
import 'review_widgets.dart';

/// Reviews block of the hostel page: summary, the three most recent reviews, and a way to the full list.
class HostelReviewsSection extends ConsumerWidget {
  const HostelReviewsSection({super.key, required this.slug, required this.reviewCount});
  final String slug;
  final int reviewCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reviewCount == 0) {
      return const SurfaceCard(child: Text('No reviews yet. Guests can review after they have stayed.'));
    }
    final summary = ref.watch(reviewSummaryProvider(slug));
    final reviews = ref.watch(hostelReviewsProvider(ReviewsQuery(slug)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summary.when(
          loading: () => const Skeleton(child: SkeletonBox(height: 110, radius: 16)),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(reviewSummaryProvider(slug))),
          data: (s) => ReviewSummaryView(summary: s),
        ),
        const SizedBox(height: 20),
        reviews.when(
          loading: () => const Skeleton(child: Column(children: [SkeletonBox(height: 90, radius: 12), SizedBox(height: 12), SkeletonBox(height: 90, radius: 12)])),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(hostelReviewsProvider(ReviewsQuery(slug)))),
          data: (page) => Column(
            children: [
              for (final r in page.items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ReviewTile(review: r),
                ),
            ],
          ),
        ),
        if (reviewCount > 3) AppButton(label: 'Show all ${count(reviewCount)} reviews', onPressed: () => context.push(Routes.hostelReviews(slug)), variant: AppButtonVariant.secondary),
      ],
    );
  }
}
