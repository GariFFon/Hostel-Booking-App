import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../hostels/domain/hostel_models.dart';

class WishlistRepository {
  WishlistRepository(this._api);

  final ApiClient _api;

  Future<Set<String>> ids() async {
    final data = asMap((await _api.get('/me/wishlist/ids')).data);
    return {for (final id in (data['hostelIds'] as List? ?? const [])) id as String};
  }

  Future<Paged<WishlistEntry>> list({String? cursor}) => _api.getPage('/me/wishlist', WishlistEntry.fromJson, query: {'cursor': cursor, 'limit': 20});

  Future<void> add(String hostelId) => _api.put('/me/wishlist/$hostelId');

  Future<void> remove(String hostelId) => _api.delete('/me/wishlist/$hostelId');
}
