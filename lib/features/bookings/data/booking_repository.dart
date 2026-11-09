import '../../../core/format/format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../domain/booking_models.dart';
import '../domain/payment_models.dart';
import '../domain/quote_models.dart';

/// One passenger on a booking, as the backend wants it.
class GuestInput {
  const GuestInput({required this.fullName, this.gender, this.age});
  final String fullName;
  final String? gender;
  final int? age;

  Map<String, Object?> toJson() => {'fullName': fullName.trim(), 'gender': ?gender, 'age': ?age};
}

/// What the guest picked: a room type and how many beds/rooms.
class RoomSelection {
  const RoomSelection(this.roomTypeId, this.units);
  final String roomTypeId;
  final int units;
  Map<String, Object?> toJson() => {'roomTypeId': roomTypeId, 'units': units};
}

class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  Future<Quote> quote({
    required String hostelId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required List<RoomSelection> items,
    String? couponCode,
  }) => _api.postOne(
    '/quotes',
    Quote.fromJson,
    body: {
      'hostelId': hostelId,
      'checkIn': toApiDate(checkIn),
      'checkOut': toApiDate(checkOut),
      'guests': guests,
      'items': items.map((i) => i.toJson()).toList(),
      if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim(),
    },
  );

  /// [idempotencyKey] is generated once per user action and reused on every retry of that action.
  Future<Booking> create({
    required String idempotencyKey,
    required String hostelId,
    required DateTime checkIn,
    required DateTime checkOut,
    required List<RoomSelection> items,
    required List<GuestInput> guests,
    required String contactPhone,
    String? couponCode,
    String? specialRequests,
    required int expectedTotalPaise,
  }) => _api.postOne(
    '/bookings',
    Booking.fromJson,
    headers: {'Idempotency-Key': idempotencyKey},
    body: {
      'hostelId': hostelId,
      'checkIn': toApiDate(checkIn),
      'checkOut': toApiDate(checkOut),
      'items': items.map((i) => i.toJson()).toList(),
      'guests': guests.map((g) => g.toJson()).toList(),
      'contactPhone': contactPhone.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim(),
      if (specialRequests != null && specialRequests.trim().isNotEmpty) 'specialRequests': specialRequests.trim(),
      'expectedTotalPaise': expectedTotalPaise,
    },
  );

  Future<Paged<BookingSummary>> list({String when = 'all', String? cursor, int limit = 20}) =>
      _api.getPage('/bookings', BookingSummary.fromJson, query: {'when': when, 'limit': limit, 'cursor': cursor});

  Future<Booking> detail(String id) => _api.getOne('/bookings/$id', Booking.fromJson);

  Future<CancellationPreview> cancellationPreview(String id) => _api.getOne('/bookings/$id/cancellation-preview', CancellationPreview.fromJson);

  Future<Booking> cancel(String id, {String? reason}) =>
      _api.postOne('/bookings/$id/cancel', Booking.fromJson, body: {if (reason != null && reason.trim().length >= 3) 'reason': reason.trim()});

  /// Starts or resumes payment. A retry after a failure returns a fresh order.
  Future<PaymentOrder> startPayment(String bookingId, {required String idempotencyKey}) =>
      _api.postOne('/bookings/$bookingId/payments', PaymentOrder.fromJson, headers: {'Idempotency-Key': idempotencyKey});

  Future<PaymentOrder> payment(String paymentId) => _api.getOne('/payments/$paymentId', PaymentOrder.fromJson);

  /// Demo gateway only: pays with a test instrument. Confirmation still arrives by webhook, so callers poll afterwards.
  Future<PaymentOrder> demoCheckout(String paymentId, {required String instrument, String method = 'UPI'}) =>
      _api.postOne('/payments/$paymentId/demo-checkout', PaymentOrder.fromJson, body: {'instrument': instrument, 'method': method});
}
