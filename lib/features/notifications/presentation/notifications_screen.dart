import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../application/notification_providers.dart';
import '../domain/notification_models.dart';

/// The in-app inbox. Tapping a row marks it read and opens whatever it is about; swiping removes it.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Host-facing notifications open the host view of the same booking.
  String? _target(NotificationItem n) {
    final booking = n.bookingId;
    switch (n.type) {
      case NotificationType.bookingApprovalRequested:
        return booking == null ? Routes.host : Routes.hostBooking(booking);
      case NotificationType.reviewReceived:
        return Routes.hostReviews;
      case NotificationType.hostelApproved:
      case NotificationType.hostelRejected:
        return Routes.hostListings;
      case NotificationType.reviewReplied:
        return Routes.myReviews;
      default:
        return booking == null ? null : Routes.booking(booking);
    }
  }

  IconData _icon(NotificationType t) => switch (t) {
    NotificationType.bookingConfirmed || NotificationType.bookingApproved => Icons.check_circle_outline_rounded,
    NotificationType.bookingRejected || NotificationType.bookingCancelled || NotificationType.bookingExpired => Icons.event_busy_outlined,
    NotificationType.bookingApprovalRequested || NotificationType.bookingCreated => Icons.luggage_outlined,
    NotificationType.bookingReminder => Icons.alarm_rounded,
    NotificationType.paymentSucceeded => Icons.payments_outlined,
    NotificationType.paymentFailed => Icons.error_outline_rounded,
    NotificationType.refundProcessed => Icons.undo_rounded,
    NotificationType.reviewRequested || NotificationType.reviewReceived || NotificationType.reviewReplied => Icons.star_outline_rounded,
    NotificationType.hostelApproved || NotificationType.hostelRejected => Icons.home_work_outlined,
    NotificationType.kycApproved || NotificationType.kycRejected => Icons.verified_user_outlined,
    _ => Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final state = ref.watch(notificationsProvider);
    final hasUnread = state.value?.items.any((n) => !n.read) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            AppButton(
              label: 'Mark all read',
              variant: AppButtonVariant.ghost,
              expand: false,
              compact: true,
              onPressed: () async {
                try {
                  await ref.read(notificationsProvider.notifier).markAllRead();
                } catch (e) {
                  if (context.mounted) showErrorToast(context, e);
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: PagedScroll(
        value: state,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        separator: 0,
        onLoadMore: () => ref.read(notificationsProvider.notifier).loadMore(),
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.read(unreadCountProvider.notifier).refresh();
          await ref.read(notificationsProvider.future);
        },
        empty: const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'All caught up',
          message: 'Booking updates, payments and review replies show up here.',
        ),
        itemBuilder: (context, n, _) {
          final target = _target(n);
          return Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: c.destructive,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) => ref.read(notificationsProvider.notifier).remove(n),
            child: Pressable(
              scale: 0.995,
              semanticLabel: '${n.read ? '' : 'Unread. '}${n.title}. ${n.body}. ${relativeTime(n.createdAt)}',
              onTap: () async {
                if (!n.read) ref.read(notificationsProvider.notifier).markRead(n);
                if (target != null) context.push(target);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: n.read ? null : c.accent.withValues(alpha: 0.35),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle),
                      child: Icon(_icon(n.type), size: 20, color: c.mutedForeground),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: n.read ? t.bodyLarge : t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (n.body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                n.body,
                                style: t.bodyMedium?.copyWith(color: c.mutedForeground),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(relativeTime(n.createdAt), style: t.bodySmall),
                          ),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 6),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
