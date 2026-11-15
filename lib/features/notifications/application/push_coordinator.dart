import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/application/session.dart';
import '../domain/notification_models.dart';
import '../data/push_service.dart';
import '../presentation/notification_routes.dart';
import 'notification_providers.dart';
import 'push_registration.dart';

/// Wires push into the app: while someone is signed in it asks for permission, registers this phone, keeps the token fresh,
/// refreshes the inbox when a push arrives with the app open, and opens the right screen when a push is tapped.
/// Watch it once from the app root.
final pushCoordinatorProvider = Provider<void>((ref) {
  final service = ref.watch(pushServiceProvider);
  final userId = ref.watch(userIdProvider);
  if (!service.available || userId == null) return;

  final subs = <StreamSubscription<Object?>>[];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });

  void open(PushPayload p) {
    final target = notificationRoute(_asItem(p));
    if (target != null) ref.read(routerProvider).push(target);
  }

  unawaited(() async {
    final token = await service.start();
    if (token != null) await ref.read(pushRegistrationProvider).register(token);
    final launch = await service.launchedBy();
    if (launch != null) open(launch);
  }());

  subs.add(service.tokenChanges.listen((t) => ref.read(pushRegistrationProvider).register(t)));
  subs.add(
    service.foreground.listen((_) {
      ref.invalidate(notificationsProvider);
      ref.read(unreadCountProvider.notifier).refresh();
    }),
  );
  subs.add(service.opened.listen(open));
});

NotificationItem _asItem(PushPayload p) => NotificationItem(
  id: p.notificationId ?? '',
  type: NotificationType.values.asNameMap()[_camel(p.type)] ?? NotificationType.unknown,
  title: p.title,
  body: p.body,
  data: p.data,
  createdAt: DateTime.now(),
);

/// RENT_OVERDUE -> rentOverdue
String _camel(String screaming) {
  final parts = screaming.toLowerCase().split('_');
  return parts.first + parts.skip(1).map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join();
}
