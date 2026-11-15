import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../domain/notification_models.dart';

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<Paged<NotificationItem>> list({String? cursor, bool unreadOnly = false}) =>
      _api.getPage('/me/notifications', NotificationItem.fromJson, query: {'cursor': cursor, 'limit': 25, 'unread': unreadOnly ? 'true' : null});

  Future<int> unreadCount() async => (asMap((await _api.get('/me/notifications/unread-count')).data)['unread'] as num? ?? 0).toInt();

  Future<void> markRead(String id) => _api.post('/me/notifications/$id/read');

  Future<void> readAll() => _api.post('/me/notifications/read-all');

  Future<void> delete(String id) => _api.delete('/me/notifications/$id');

  /// Registers this phone for push and returns the server's id for it (needed to remove it again).
  Future<String> registerDevice({required String platform, required String pushToken}) async =>
      asMap((await _api.post('/me/devices', body: {'platform': platform, 'pushToken': pushToken})).data)['id'] as String;

  Future<void> removeDevice(String id) => _api.delete('/me/devices/$id');

  Future<NotificationPrefs> prefs() => _api.getOne('/me/notification-preferences', NotificationPrefs.fromJson);

  Future<NotificationPrefs> updatePrefs({
    bool? emailBookings,
    bool? emailMarketing,
    bool? inAppBookings,
    bool? inAppReviews,
    bool? inAppRent,
    bool? emailRent,
    bool? inAppComplaints,
  }) async => NotificationPrefs.fromJson(
    asMap(
      (await _api.patch(
        '/me/notification-preferences',
        body: {
          'emailBookings': ?emailBookings,
          'emailMarketing': ?emailMarketing,
          'inAppBookings': ?inAppBookings,
          'inAppReviews': ?inAppReviews,
          'inAppRent': ?inAppRent,
          'emailRent': ?emailRent,
          'inAppComplaints': ?inAppComplaints,
        },
      )).data,
    ),
  );
}
