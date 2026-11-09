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

  Future<NotificationPrefs> prefs() => _api.getOne('/me/notification-preferences', NotificationPrefs.fromJson);

  Future<NotificationPrefs> updatePrefs({bool? emailBookings, bool? emailMarketing, bool? inAppBookings, bool? inAppReviews}) async =>
      NotificationPrefs.fromJson(
        asMap(
          (await _api.patch(
            '/me/notification-preferences',
            body: {
              'emailBookings': ?emailBookings,
              'emailMarketing': ?emailMarketing,
              'inAppBookings': ?inAppBookings,
              'inAppReviews': ?inAppReviews,
            },
          )).data,
        ),
      );
}
