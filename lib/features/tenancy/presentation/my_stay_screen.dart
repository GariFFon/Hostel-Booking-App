import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/states.dart';
import '../application/tenancy_providers.dart';
import '../../rent/presentation/my_rent_section.dart';
import '../domain/tenancy_models.dart';
import 'leaving_widgets.dart';

Tone tenancyTone(TenancyStatus s) => switch (s) {
  TenancyStatus.active => Tone.success,
  TenancyStatus.pendingMoveIn || TenancyStatus.notice => Tone.warning,
  TenancyStatus.invited => Tone.info,
  _ => Tone.neutral,
};

Tone applicationTone(ApplicationStatus s) => switch (s) {
  ApplicationStatus.requested => Tone.warning,
  ApplicationStatus.approved => Tone.success,
  ApplicationStatus.rejected => Tone.danger,
  _ => Tone.neutral,
};

/// Where the student lives, and the requests they have sent.
class MyStayScreen extends ConsumerStatefulWidget {
  const MyStayScreen({super.key});

  @override
  ConsumerState<MyStayScreen> createState() => _MyStayScreenState();
}

class _MyStayScreenState extends ConsumerState<MyStayScreen> {
  @override
  void initState() {
    super.initState();
    // A stay can be created while the app is open (an owner adds you), so never trust a list loaded earlier.
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(myTenanciesProvider);
      ref.invalidate(myApplicationsProvider);
    });
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<Object?> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(myTenanciesProvider);
      ref.invalidate(myApplicationsProvider);
      if (context.mounted) showToast(context, done);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stays = ref.watch(myTenanciesProvider);
    final apps = ref.watch(myApplicationsProvider);
    final repo = ref.read(tenancyRepositoryProvider);
    final error = stays.error ?? apps.error;

    Widget body;
    if (error != null) {
      body = ErrorState(
        error: error,
        onRetry: () {
          ref.invalidate(myTenanciesProvider);
          ref.invalidate(myApplicationsProvider);
        },
      );
    } else if (stays.isLoading || apps.isLoading) {
      body = const CardSkeletonList();
    } else {
      final s = stays.value?.items ?? const <Tenancy>[];
      final a = apps.value?.items ?? const <TenancyApplication>[];
      final open = a.where((x) => x.status == ApplicationStatus.requested).toList();
      final earlier = a.where((x) => x.status != ApplicationStatus.requested).toList();
      if (s.isEmpty && a.isEmpty) {
        body = LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: EmptyState(
                icon: Icons.house_outlined,
                title: 'No stay yet',
                message: 'Find a hostel or PG and ask for a bed. Your request and where you live show up here. Pull down to refresh.',
                actionLabel: 'Find a place',
                onAction: () => context.go('/'),
              ),
            ),
          ),
        );
      } else {
        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final t in s) ...[
              _StayCard(
                tenancy: t,
                onAccept: () => _run(context, ref, () => repo.accept(t.id), 'Invitation accepted'),
                onDecline: () async {
                  if (await confirmAction(
                        context,
                        title: 'Decline this stay?',
                        message: 'The bed goes back to the owner.',
                        confirmLabel: 'Decline',
                        destructive: true,
                      ) &&
                      context.mounted) {
                    await _run(context, ref, () => repo.decline(t.id), 'Declined');
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            if (s.isNotEmpty) ...[const MyRentSection(), const SizedBox(height: 12)],
            if (open.isNotEmpty) ...[
              const SectionTitle('Open requests'),
              for (final x in open) ...[
                _ApplicationCard(app: x, onWithdraw: () => _run(context, ref, () => repo.withdraw(x.id), 'Request withdrawn')),
                const SizedBox(height: 12),
              ],
            ],
            if (earlier.isNotEmpty) ...[
              const SectionTitle('Earlier requests'),
              for (final x in earlier) ...[_ApplicationCard(app: x), const SizedBox(height: 12)],
            ],
          ],
        );
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My stay')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(myTenanciesProvider);
          ref.invalidate(myApplicationsProvider);
          await ref.read(myTenanciesProvider.future);
        },
        child: body,
      ),
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({required this.tenancy, required this.onAccept, required this.onDecline});
  final Tenancy tenancy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final x = tenancy;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(x.hostel.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              StatusChip(x.status.label, tone: tenancyTone(x.status)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${x.roomType.name} · bed ${x.unit.label} · ${x.hostel.city}', style: t.bodySmall),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: money(x.rentPaise), style: t.titleLarge?.tabular),
                TextSpan(text: ' / month', style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Move-in ${fmtLong(x.start)} · rent due on the ${ordinal(x.dueDay)}', style: t.bodySmall),
          Text(
            x.deposit.status == 'NONE' ? 'No deposit' : 'Deposit ${money(x.depositPaise)} · ${x.deposit.isReceived ? 'received' : 'due'}',
            style: t.bodySmall,
          ),
          if (x.status == TenancyStatus.pendingMoveIn) ...[
            const SizedBox(height: 8),
            Text(
              x.deposit.isDue
                  ? 'Your bed is reserved. Pay the deposit to the owner before move-in; they will record it.'
                  : 'Your bed is reserved. The owner will confirm your move-in.',
              style: t.bodySmall?.copyWith(color: c.mutedForeground),
            ),
          ],
          TenantLeavingSection(tenancy: x),
          if (x.can('accept') || x.can('decline')) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (x.can('accept'))
                  Expanded(
                    child: AppButton(label: 'Accept', onPressed: onAccept, compact: true),
                  ),
                if (x.can('accept') && x.can('decline')) const SizedBox(width: 12),
                if (x.can('decline'))
                  Expanded(
                    child: AppButton(label: 'Decline', onPressed: onDecline, variant: AppButtonVariant.secondary, compact: true),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, this.onWithdraw});
  final TenancyApplication app;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(app.hostel.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              StatusChip(app.status.label, tone: applicationTone(app.status)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${app.roomType.name} · move in ${fmtLong(app.moveIn)}', style: t.bodySmall),
          if (app.decisionNote != null) ...[const SizedBox(height: 6), Text('Owner\'s note: ${app.decisionNote}', style: t.bodySmall)],
          if (app.can('withdraw') && onWithdraw != null) ...[
            const SizedBox(height: 10),
            AppButton(label: 'Withdraw', onPressed: onWithdraw, variant: AppButtonVariant.secondary, compact: true, expand: false),
          ],
        ],
      ),
    );
  }
}
