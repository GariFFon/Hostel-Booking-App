import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../domain/notification_models.dart';

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, PageState<NotificationItem>>(NotificationsNotifier.new);

class NotificationsNotifier extends PagedNotifier<NotificationItem> {
  @override
  Future<PageState<NotificationItem>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<NotificationItem>> fetch(String? cursor) => ref.read(notificationRepositoryProvider).list(cursor: cursor);

  Future<void> markRead(NotificationItem item) async {
    if (item.read) return;
    edit((items) => [for (final i in items) i.id == item.id ? i.asRead() : i]);
    ref.read(unreadCountProvider.notifier).decrement();
    try {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
    } catch (_) {
      ref.invalidateSelf();
      ref.invalidate(unreadCountProvider);
    }
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).readAll();
    edit((items) => [for (final i in items) i.asRead()]);
    ref.read(unreadCountProvider.notifier).setZero();
  }

  Future<void> remove(NotificationItem item) async {
    edit((items) => items.where((i) => i.id != item.id).toList());
    if (!item.read) ref.read(unreadCountProvider.notifier).decrement();
    try {
      await ref.read(notificationRepositoryProvider).delete(item.id);
    } catch (_) {
      ref.invalidateSelf();
      ref.invalidate(unreadCountProvider);
    }
  }
}

/// The badge. Cheap endpoint, polled once a minute while signed in; failures keep the last known count.
final unreadCountProvider = AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (ref.watch(userIdProvider) == null) return 0;
    final timer = Timer.periodic(const Duration(seconds: 60), (_) => _poll());
    ref.onDispose(timer.cancel);
    return ref.read(notificationRepositoryProvider).unreadCount();
  }

  Future<void> _poll() async {
    try {
      final n = await ref.read(notificationRepositoryProvider).unreadCount();
      if (ref.mounted) state = AsyncData(n);
    } catch (_) {
      // Keep whatever we last knew; the badge must never flash an error.
    }
  }

  Future<void> refresh() => _poll();

  void decrement() => state = AsyncData(((state.value ?? 0) - 1).clamp(0, 1 << 30));

  void setZero() => state = const AsyncData(0);
}

final notificationPrefsProvider = AsyncNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(NotificationPrefsNotifier.new);

class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const NotificationPrefs());
    return ref.read(notificationRepositoryProvider).prefs();
  }

  /// Optimistic switch; reverts (and rethrows) when the server refuses.
  Future<void> change(NotificationPrefs Function(NotificationPrefs p) edit) async {
    final before = state.value;
    if (before == null) return;
    final next = edit(before);
    state = AsyncData(next);
    try {
      state = AsyncData(
        await ref
            .read(notificationRepositoryProvider)
            .updatePrefs(
              emailBookings: next.emailBookings,
              emailMarketing: next.emailMarketing,
              inAppBookings: next.inAppBookings,
              inAppReviews: next.inAppReviews,
            ),
      );
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}
