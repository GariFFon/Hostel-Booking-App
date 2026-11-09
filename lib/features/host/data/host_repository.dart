import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../bookings/domain/booking_models.dart';
import '../../reviews/domain/review_models.dart';
import '../domain/host_models.dart';

/// The host's view of the platform: their bookings, earnings, listings (read-only here) and reviews.
class HostRepository {
  HostRepository(this._api);

  final ApiClient _api;

  Future<Paged<BookingSummary>> bookings({String when = 'all', String? status, String? hostelId, String? cursor}) =>
      _api.getPage('/owner/bookings', BookingSummary.fromJson, query: {'when': when, 'status': status, 'hostelId': hostelId, 'cursor': cursor, 'limit': 20});

  Future<Booking> booking(String id) => _api.getOne('/owner/bookings/$id', Booking.fromJson);

  Future<Booking> approve(String id) => _api.postOne('/owner/bookings/$id/approve', Booking.fromJson);

  Future<Booking> reject(String id, String reason) => _api.postOne('/owner/bookings/$id/reject', Booking.fromJson, body: {'reason': reason.trim()});

  Future<Booking> checkIn(String id) => _api.postOne('/owner/bookings/$id/check-in', Booking.fromJson);

  Future<Booking> complete(String id) => _api.postOne('/owner/bookings/$id/complete', Booking.fromJson);

  Future<Booking> noShow(String id) => _api.postOne('/owner/bookings/$id/no-show', Booking.fromJson);

  Future<Booking> cancel(String id, String reason) => _api.postOne('/owner/bookings/$id/cancel', Booking.fromJson, body: {'reason': reason.trim()});

  Future<Earnings> earnings() => _api.getOne('/owner/earnings', Earnings.fromJson);

  Future<Paged<OwnerHostel>> hostels({String? cursor}) => _api.getPage('/owner/hostels', OwnerHostel.fromJson, query: {'cursor': cursor, 'limit': 30});

  Future<Paged<Review>> reviews({bool? replied, String? cursor}) =>
      _api.getPage('/owner/reviews', Review.fromJson, query: {'replied': replied?.toString(), 'cursor': cursor, 'limit': 20});

  Future<void> reply(String reviewId, String text) => _api.put('/owner/reviews/$reviewId/reply', body: {'text': text.trim()});

  Future<void> deleteReply(String reviewId) => _api.delete('/owner/reviews/$reviewId/reply');

  Future<void> report(String reviewId, String reason) => _api.post('/owner/reviews/$reviewId/report', body: {'reason': reason.trim()});
}
