import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';
import '../../auth/presentation/sign_in_prompt.dart';
import '../application/booking_providers.dart';
import 'booking_card.dart';

/// The Trips tab: what is coming up (including bookings waiting for payment or approval) and what is over.
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  String _when = 'upcoming';

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(userIdProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: !signedIn
          ? const SignInPrompt(
              icon: Icons.luggage_outlined,
              title: 'Your trips live here',
              message: 'Sign in to see your bookings, pay for a stay you started, or leave a review.',
              next: Routes.trips,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: AppSegmented<String>(
                    semanticLabel: 'Trips filter',
                    options: const [(value: 'upcoming', label: 'Upcoming'), (value: 'past', label: 'Past')],
                    value: _when,
                    onChanged: (v) => setState(() => _when = v),
                  ),
                ),
                Expanded(child: _TripList(when: _when)),
              ],
            ),
    );
  }
}

class _TripList extends ConsumerWidget {
  const _TripList({required this.when});
  final String when;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = bookingListProvider(when);
    final upcoming = when == 'upcoming';
    return PagedScroll(
      key: ValueKey(when),
      value: ref.watch(provider),
      onLoadMore: () => ref.read(provider.notifier).loadMore(),
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      empty: upcoming
          ? EmptyState(
              icon: Icons.luggage_outlined,
              title: 'No trips planned yet',
              message: 'When you book a stay it shows up here, with everything you need on the day.',
              actionLabel: 'Find a stay',
              onAction: () => context.go(Routes.explore),
            )
          : const EmptyState(icon: Icons.history_rounded, title: 'No past trips', message: 'Completed, cancelled and expired bookings appear here.'),
      itemBuilder: (context, b, _) => BookingCard(booking: b, onTap: () => context.push(Routes.booking(b.id))),
    );
  }
}
