import 'package:dio/dio.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../domain/hostel_models.dart';
import 'search_params.dart';

class HostelRepository {
  HostelRepository(this._api);

  final ApiClient _api;

  Future<Paged<HostelCard>> search(SearchParams p, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _api.getPage('/hostels', HostelCard.fromJson, query: p.toQuery(cursor: cursor, limit: limit), cancel: cancel);

  /// Markers inside a bounding box (`minLng,minLat,maxLng,maxLat`) with the same filters as the list.
  Future<List<MapMarker>> mapMarkers(SearchParams p, {required String bbox, CancelToken? cancel}) {
    final q = p.toQuery(limit: 300)
      ..remove('cursor')
      ..remove('sort')
      ..['bbox'] = bbox;
    return _api.getList('/hostels/map', MapMarker.fromJson, query: q, cancel: cancel);
  }

  Future<HostelDetail> detail(String idOrSlug) => _api.getOne('/hostels/$idOrSlug', HostelDetail.fromJson);

  Future<Availability> availability(String idOrSlug, {required DateTime checkIn, required DateTime checkOut, required int guests}) =>
      _api.getOne('/hostels/$idOrSlug/availability', Availability.fromJson,
          query: {'checkIn': toApiDate(checkIn), 'checkOut': toApiDate(checkOut), 'guests': guests});

  Future<List<Offer>> offers(String idOrSlug) => _api.getList('/hostels/$idOrSlug/offers', Offer.fromJson);

  Future<Suggestions> suggest(String q, {CancelToken? cancel}) => _api.getOne('/search/suggest', Suggestions.fromJson, query: {'q': q}, cancel: cancel);

  Future<List<CityStat>> cities() => _api.getList('/cities', CityStat.fromJson);

  Future<List<Amenity>> amenities() => _api.getList('/amenities', Amenity.fromJson);
}
