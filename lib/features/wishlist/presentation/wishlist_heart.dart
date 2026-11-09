import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/pressable.dart';
import '../../auth/application/session.dart';
import '../application/wishlist_providers.dart';

/// Heart on a card or detail page. Optimistic: flips at once, reverts with a message if the server says no.
/// Signed-out visitors are sent to sign in and come back to where they were.
class WishlistHeart extends ConsumerWidget {
  const WishlistHeart({super.key, required this.hostelId, this.hostelName});

  final String hostelId;
  final String? hostelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final saved = ref.watch(wishlistIdsProvider.select((a) => a.value?.contains(hostelId) ?? false));
    final label = hostelName == null ? (saved ? 'Remove from saved' : 'Save') : (saved ? 'Remove $hostelName from saved' : 'Save $hostelName');

    return Pressable(
      semanticLabel: label,
      minSize: const Size(kMinTap, kMinTap),
      haptic: true,
      scale: 0.9,
      onTap: () async {
        if (ref.read(currentUserProvider) == null) {
          final here = GoRouterState.of(context).uri.toString();
          context.push('/login?next=${Uri.encodeComponent(here)}');
          return;
        }
        try {
          await ref.read(wishlistIdsProvider.notifier).toggle(hostelId);
        } catch (e) {
          if (context.mounted) showErrorToast(context, e);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.card.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: saved ? c.primary : c.foreground),
      ),
    );
  }
}
