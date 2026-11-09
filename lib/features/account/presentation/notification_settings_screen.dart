import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/states.dart';
import '../../notifications/application/notification_providers.dart';
import '../../notifications/domain/notification_models.dart';

/// Four switches. Each flips at once and is put back with a message if the server refuses.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: prefs.when(
        loading: () => const RowSkeletonList(count: 4),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(notificationPrefsProvider)),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Group(
              title: 'Bookings',
              children: [
                _Switch(label: 'Booking emails', subtitle: 'Confirmations, changes and receipts', value: p.emailBookings, onChanged: (v) => _set(context, ref, (x) => x.copyWith(emailBookings: v))),
                _Switch(label: 'Booking alerts in the app', subtitle: 'Approvals, payments, reminders', value: p.inAppBookings, onChanged: (v) => _set(context, ref, (x) => x.copyWith(inAppBookings: v))),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              title: 'Reviews and offers',
              children: [
                _Switch(label: 'Review alerts in the app', subtitle: 'Review prompts after a stay, and replies from hosts', value: p.inAppReviews, onChanged: (v) => _set(context, ref, (x) => x.copyWith(inAppReviews: v))),
                _Switch(label: 'Offers and tips by email', subtitle: 'Occasional. Never required to book', value: p.emailMarketing, onChanged: (v) => _set(context, ref, (x) => x.copyWith(emailMarketing: v))),
              ],
            ),
            const SizedBox(height: 16),
            Text('Important account and security emails are always sent.', style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, NotificationPrefs Function(NotificationPrefs) edit) async {
    try {
      await ref.read(notificationPrefsProvider.notifier).change(edit);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(title, style: context.text.labelMedium?.copyWith(color: c.mutedForeground))),
        Container(
          decoration: BoxDecoration(color: c.card, borderRadius: Radii.cardR, border: Border.all(color: c.border)),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.label, required this.subtitle, required this.value, required this.onChanged});
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: context.text.bodyLarge),
        subtitle: Text(subtitle, style: context.text.bodySmall),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
