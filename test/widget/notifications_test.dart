import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/account/presentation/notification_settings_screen.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/notifications/application/notification_providers.dart';
import 'package:hostel_booking_app/features/notifications/data/notification_repository.dart';
import 'package:hostel_booking_app/features/notifications/domain/notification_models.dart';
import 'package:hostel_booking_app/features/notifications/presentation/notifications_screen.dart';

import '../support/support.dart';

class _FakeNotifications implements NotificationRepository {
  NotificationPrefs prefsData = const NotificationPrefs();
  final updates = <Map<String, bool?>>[];
  bool failUpdate = false;
  List<NotificationItem> items = const [];

  @override
  Future<String> registerDevice({required String platform, required String pushToken}) async => 'dev';

  @override
  Future<void> removeDevice(String id) async {}

  @override
  Future<NotificationPrefs> prefs() async => prefsData;

  @override
  Future<NotificationPrefs> updatePrefs({
    bool? emailBookings,
    bool? emailMarketing,
    bool? inAppBookings,
    bool? inAppReviews,
    bool? inAppRent,
    bool? emailRent,
    bool? inAppComplaints,
  }) async {
    if (failUpdate) throw Exception('no');
    updates.add({'inAppRent': inAppRent, 'emailRent': emailRent, 'inAppComplaints': inAppComplaints});
    prefsData = NotificationPrefs(
      emailBookings: emailBookings ?? prefsData.emailBookings,
      emailMarketing: emailMarketing ?? prefsData.emailMarketing,
      inAppBookings: inAppBookings ?? prefsData.inAppBookings,
      inAppReviews: inAppReviews ?? prefsData.inAppReviews,
      inAppRent: inAppRent ?? prefsData.inAppRent,
      emailRent: emailRent ?? prefsData.emailRent,
      inAppComplaints: inAppComplaints ?? prefsData.inAppComplaints,
    );
    return prefsData;
  }

  @override
  Future<Paged<NotificationItem>> list({String? cursor, bool unreadOnly = false}) async => Paged(items: items);

  @override
  Future<int> unreadCount() async => items.where((i) => !i.read).length;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> readAll() async {}

  @override
  Future<void> delete(String id) async {}
}

NotificationItem item(String type, String title) => NotificationItem.fromJson({
  'id': title,
  'type': type,
  'title': title,
  'body': '',
  'data': null,
  'read': false,
  'readAt': null,
  'createdAt': '2027-01-01T00:00:00Z',
});

void main() {
  setUpAll(initLocale);

  group('notification settings', () {
    Future<_FakeNotifications> open(WidgetTester t, {NotificationPrefs? prefs}) async {
      final repo = _FakeNotifications();
      if (prefs != null) repo.prefsData = prefs;
      await pumpScreen(
        t,
        const NotificationSettingsScreen(),
        overrides: [sessionProvider.overrideWith(() => FakeSession(guestUser)), notificationRepositoryProvider.overrideWithValue(repo)],
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('has switches for stay and rent, rent emails and complaints, all on by default', (t) async {
      await open(t);
      expect(find.text('Stay, rent and deposit alerts in the app'), findsOneWidget);
      expect(find.text('Rent bill and reminder emails'), findsOneWidget);
      expect(find.text('Complaint alerts in the app'), findsOneWidget);
      final switches = t.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 7);
      expect(switches.where((s) => s.value).length, 6); // only offers-by-email is off
    });

    testWidgets('turning one off sends just that switch and the others stay as they were', (t) async {
      final repo = await open(t);
      await t.tap(find.text('Complaint alerts in the app'));
      await t.pumpAndSettle();
      expect(repo.updates.single, {'inAppRent': true, 'emailRent': true, 'inAppComplaints': false});
      expect(repo.prefsData.inAppComplaints, false);
      await t.tap(find.text('Rent bill and reminder emails'));
      await t.pumpAndSettle();
      expect(repo.prefsData.emailRent, false);
      expect(repo.prefsData.inAppRent, true);
    });

    testWidgets('a refused change puts the switch back and says so', (t) async {
      final repo = await open(t, prefs: const NotificationPrefs(inAppRent: true));
      repo.failUpdate = true;
      await t.tap(find.text('Stay, rent and deposit alerts in the app'));
      await t.pumpAndSettle();
      final tile = t.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Stay, rent and deposit alerts in the app'));
      expect(tile.value, true);
    });
  });

  group('the notification list', () {
    testWidgets('rent, deposit, complaint and staff notifications each get their own icon', (t) async {
      final repo = _FakeNotifications()
        ..items = [
          item('RENT_OVERDUE', 'Rent overdue'),
          item('DEPOSIT_SETTLED', 'Deposit settled'),
          item('COMPLAINT_CREATED', 'Complaint filed'),
          item('COMPLAINT_ASSIGNED', 'Complaint assigned'),
          item('COMPLAINT_UPDATED', 'Visit booked'),
          item('COMPLAINT_RESOLVED', 'Complaint resolved'),
          item('STAFF_INVITED', 'Join the team'),
        ];
      await pumpScreen(
        t,
        const NotificationsScreen(),
        overrides: [
          sessionProvider.overrideWith(() => FakeSession(guestUser)),
          notificationRepositoryProvider.overrideWithValue(repo),
          unreadCountProvider.overrideWith(_Zero.new),
        ],
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      for (final icon in [
        Icons.warning_amber_rounded,
        Icons.account_balance_wallet_outlined,
        Icons.report_problem_outlined,
        Icons.assignment_ind_outlined,
        Icons.build_circle_outlined,
        Icons.task_alt_rounded,
        Icons.engineering_outlined,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
      }
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing); // none falls back to the generic bell
    });
  });
}

class _Zero extends UnreadCountNotifier {
  @override
  Future<int> build() async => 0;
}
