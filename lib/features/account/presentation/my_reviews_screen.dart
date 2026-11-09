import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/states.dart';
import '../../reviews/application/review_providers.dart';
import '../../reviews/domain/review_models.dart';
import '../../reviews/presentation/review_form_sheet.dart';
import '../../reviews/presentation/review_widgets.dart';

enum _Menu { edit, delete }

String _editLabel(Review r) {
  final until = r.editableUntil == null ? null : DateTime.tryParse(r.editableUntil!)?.toLocal();
  return until == null ? 'Edit' : 'Edit (until ${fmtShort(until)})';
}

/// Reviews the signed-in user wrote. A review can be edited for 14 days (and until the host replies), and deleted any time.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Review r) async {
    final ok = await confirmAction(context, title: 'Delete this review?', message: 'It disappears from the property page and cannot be restored.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ref.read(reviewRepositoryProvider).delete(r.id);
      ref.read(myReviewsProvider.notifier).edit((items) => items.where((e) => e.id != r.id).toList());
      ref.invalidate(hostelReviewsProvider);
      ref.invalidate(reviewSummaryProvider);
      if (context.mounted) showToast(context, 'Review deleted');
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your reviews')),
      body: PagedScroll(
        value: ref.watch(myReviewsProvider),
        onLoadMore: () => ref.read(myReviewsProvider.notifier).loadMore(),
        onRefresh: () async {
          ref.invalidate(myReviewsProvider);
          await ref.read(myReviewsProvider.future);
        },
        empty: EmptyState(
          icon: Icons.star_outline_rounded,
          title: 'No reviews yet',
          message: 'After a stay you can rate it from the booking page. Your review helps other travellers.',
          actionLabel: 'See your trips',
          onAction: () => context.go(Routes.trips),
        ),
        itemBuilder: (context, r, _) => SurfaceCard(
          child: ReviewTile(
            review: r,
            showHostel: true,
            trailing: PopupMenuButton<_Menu>(
              tooltip: 'Review options',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (m) async {
                switch (m) {
                  case _Menu.edit:
                    await showReviewSheet(context, hostelName: r.hostel?.name ?? 'Your stay', existing: r);
                  case _Menu.delete:
                    await _delete(context, ref, r);
                }
              },
              itemBuilder: (_) => [
                if (r.editable) PopupMenuItem(value: _Menu.edit, child: Text(_editLabel(r))),
                const PopupMenuItem(value: _Menu.delete, child: Text('Delete')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
