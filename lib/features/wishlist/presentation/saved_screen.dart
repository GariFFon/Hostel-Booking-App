import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';
import '../../auth/presentation/sign_in_prompt.dart';
import '../../hostels/presentation/hostel_card.dart';
import '../application/wishlist_providers.dart';

/// The Saved tab: everything the signed-in user hearted. Un-hearting a card removes it from the list straight away.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(userIdProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: !signedIn
          ? const SignInPrompt(
              icon: Icons.favorite_border_rounded,
              title: 'Keep the stays you love',
              message: 'Sign in to save places and find them again on any device.',
              next: Routes.saved,
            )
          : PagedScroll(
              value: ref.watch(wishlistListProvider),
              loading: const CardSkeletonList(),
              separator: 24,
              onLoadMore: () => ref.read(wishlistListProvider.notifier).loadMore(),
              onRefresh: () async {
                ref.invalidate(wishlistListProvider);
                await ref.read(wishlistListProvider.future);
              },
              empty: EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Nothing saved yet',
                message: 'Tap the heart on a stay to keep it here.',
                actionLabel: 'Explore stays',
                onAction: () => context.go(Routes.explore),
              ),
              itemBuilder: (context, e, _) => HostelCardView(hostel: e.hostel),
            ),
    );
  }
}
