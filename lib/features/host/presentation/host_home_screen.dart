import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/application/session.dart';
import '../application/host_providers.dart';
import '../domain/host_models.dart';
import 'host_gate.dart';

/// Hosting home: money in and out, what needs a decision, and the three places hosts work.
class HostHomeScreen extends ConsumerWidget {
  const HostHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final earnings = ref.watch(earningsProvider);
    final requests = ref.watch(hostBookingsProvider(HostBookingTab.requests));
    final waiting = requests.value?.items.length ?? 0;
    final more = requests.value?.hasMore ?? false;

    return HostGate(
      title: 'Hosting',
      child: Scaffold(
        appBar: AppBar(title: const Text('Hosting')),
        body: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(earningsProvider);
            ref.invalidate(hostBookingsProvider);
            await ref.read(earningsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text('Hi ${user?.displayName ?? 'there'}', style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              if (waiting > 0) ...[
                _AttentionCard(count: waiting, more: more, onTap: () => context.push('${Routes.hostBookings}?tab=requests')),
                const SizedBox(height: 16),
              ],
              earnings.when(
                loading: () => const Skeleton(
                  child: Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 110, radius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 110, radius: 16)),
                    ],
                  ),
                ),
                error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(earningsProvider)),
                data: (e) => _EarningsRow(earnings: e),
              ),
              if (earnings.value != null && earnings.value!.byHostel.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('By property'),
                SurfaceCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < earnings.value!.byHostel.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _HostelEarningsRow(row: earnings.value!.byHostel[i]),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.luggage_outlined,
                    title: 'Bookings',
                    subtitle: 'Requests, upcoming and past',
                    badge: waiting,
                    onTap: () => context.push(Routes.hostBookings),
                  ),
                  SettingsTile(
                    icon: Icons.home_work_outlined,
                    title: 'Your listings',
                    subtitle: 'Status and details',
                    onTap: () => context.push(Routes.hostListings),
                  ),
                  SettingsTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Reviews',
                    subtitle: 'Reply to your guests',
                    onTap: () => context.push(Routes.hostReviews),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('To add a property or edit rooms, prices and photos, use the website for now.', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.count, required this.more, required this.onTap});
  final int count;
  final bool more;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final label = '${more ? '$count+' : '$count'} ${count == 1 && !more ? 'request needs' : 'requests need'} your decision';
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.tint(c.warning),
          borderRadius: Radii.baseR,
          border: Border.all(color: c.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: c.warning),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: t.titleSmall)),
            Icon(Icons.chevron_right_rounded, color: c.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.earnings});
  final Earnings earnings;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight: `stretch` alone has no height to stretch to inside a scrolling list (infinite constraint).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: 'Earned',
              value: money(earnings.settled.ownerPayablePaise),
              detail: '${plural(earnings.settled.bookings, 'stay')} completed',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Stat(
              label: 'Coming up',
              value: money(earnings.upcoming.expectedOwnerPaise),
              detail: '${plural(earnings.upcoming.bookings, 'booking')} confirmed',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.headlineSmall?.tabular, maxLines: 1),
          ),
          const SizedBox(height: 4),
          Text(detail, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _HostelEarningsRow extends StatelessWidget {
  const _HostelEarningsRow({required this.row});
  final HostelEarnings row;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: t.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(plural(row.bookings, 'booking'), style: t.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(money(row.ownerPayablePaise), style: t.titleSmall?.tabular),
      ],
    );
  }
}
