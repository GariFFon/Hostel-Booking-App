import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/format.dart';
import '../../hostels/domain/enums.dart';
import '../../hostels/domain/hostel_models.dart';

part 'booking_models.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum BookingStatus {
  hold('On hold'),
  pendingPayment('Payment due'),
  pendingApproval('Waiting for the host'),
  confirmed('Confirmed'),
  checkedIn('Checked in'),
  completed('Completed'),
  expired('Expired'),
  cancelledByGuest('Cancelled'),
  cancelledByOwner('Cancelled by host'),
  rejected('Declined'),
  noShow('No-show'),
  unknown('Unknown');

  const BookingStatus(this.label);
  final String label;

  /// Still needs something from someone (pay, or a host decision).
  bool get isPending => this == hold || this == pendingPayment || this == pendingApproval;

  /// Upcoming or in progress: the guest can still turn up.
  bool get isLive => isPending || this == confirmed || this == checkedIn;

  bool get isCancelledLike => this == cancelledByGuest || this == cancelledByOwner || this == rejected || this == expired || this == noShow;
}

/// What the viewer may do now. The UI is driven by this list, never by guessing from the status.
@JsonEnum(fieldRename: FieldRename.snake)
enum BookingAction { pay, cancel, approve, reject, checkIn, complete, noShow, review, unknown }

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ViewerRole { guest, owner, admin, unknown }

@JsonSerializable(createToJson: false)
class BookingHostelBrief {
  const BookingHostelBrief({required this.id, required this.name, this.city = '', this.coverUrl});
  final String id;
  final String name;
  final String city;
  final String? coverUrl;
  factory BookingHostelBrief.fromJson(Map<String, dynamic> json) => _$BookingHostelBriefFromJson(json);
}

DateTime? _tryDateTime(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// A row in "Your trips" / the host's booking list.
@JsonSerializable(createToJson: false)
class BookingSummary {
  const BookingSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.hostel,
    required this.checkIn,
    required this.checkOut,
    this.nights = 1,
    this.guestsCount = 1,
    this.totalPaise = 0,
    this.holdExpiresAt,
    this.guestName,
    required this.createdAt,
  });

  final String id;
  final String code;
  @JsonKey(unknownEnumValue: BookingStatus.unknown)
  final BookingStatus status;
  final BookingHostelBrief hostel;
  @JsonKey(fromJson: parseDate)
  final DateTime checkIn;
  @JsonKey(fromJson: parseDate)
  final DateTime checkOut;
  final int nights;
  final int guestsCount;
  final int totalPaise;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? holdExpiresAt;
  final String? guestName;
  final DateTime createdAt;

  factory BookingSummary.fromJson(Map<String, dynamic> json) => _$BookingSummaryFromJson(json);
}

@JsonSerializable(createToJson: false)
class BookingHostel {
  const BookingHostel({
    required this.id,
    required this.slug,
    required this.name,
    this.city = '',
    this.state = '',
    this.addressLine1 = '',
    this.locality,
    required this.location,
    this.coverUrl,
    this.checkInTime = '14:00',
    this.checkOutTime = '11:00',
    this.timezone = 'Asia/Kolkata',
    this.phone,
  });
  final String id;
  final String slug;
  final String name;
  final String city;
  final String state;
  final String addressLine1;
  final String? locality;
  final GeoPoint location;
  final String? coverUrl;
  final String checkInTime;
  final String checkOutTime;
  final String timezone;

  /// Only present once the stay is confirmed.
  final String? phone;
  factory BookingHostel.fromJson(Map<String, dynamic> json) => _$BookingHostelFromJson(json);

  String get address => [addressLine1, if (locality != null && locality!.isNotEmpty) locality!, city, state].where((s) => s.isNotEmpty).join(', ');
}

@JsonSerializable(createToJson: false)
class NightlyPrice {
  const NightlyPrice({required this.date, this.unitPricePaise = 0, this.taxBps = 0, this.isSpecialPrice = false});
  final String date;
  final int unitPricePaise;
  final int taxBps;
  final bool isSpecialPrice;
  factory NightlyPrice.fromJson(Map<String, dynamic> json) => _$NightlyPriceFromJson(json);
}

@JsonSerializable(createToJson: false)
class BookingItem {
  const BookingItem({this.roomTypeId, required this.name, this.units = 1, this.lineTotalPaise = 0, this.nightly = const []});
  final String? roomTypeId;
  final String name;
  final int units;
  final int lineTotalPaise;
  @JsonKey(defaultValue: <NightlyPrice>[])
  final List<NightlyPrice> nightly;
  factory BookingItem.fromJson(Map<String, dynamic> json) => _$BookingItemFromJson(json);
}

@JsonSerializable(createToJson: false)
class BookingGuest {
  const BookingGuest({required this.fullName, this.gender, this.age, this.idType, this.idLast4, this.isPrimary = false});
  final String fullName;
  final String? gender;
  final int? age;
  final String? idType;
  final String? idLast4;
  final bool isPrimary;
  factory BookingGuest.fromJson(Map<String, dynamic> json) => _$BookingGuestFromJson(json);
}

@JsonSerializable(createToJson: false)
class BookingPricing {
  const BookingPricing({
    this.subtotalPaise = 0,
    this.discountPaise = 0,
    this.taxPaise = 0,
    this.serviceFeePaise = 0,
    this.totalPaise = 0,
    this.effectiveGstBps = 0,
    this.couponCode,
  });
  final int subtotalPaise;
  final int discountPaise;
  final int taxPaise;
  final int serviceFeePaise;
  final int totalPaise;
  final int effectiveGstBps;
  final String? couponCode;
  factory BookingPricing.fromJson(Map<String, dynamic> json) => _$BookingPricingFromJson(json);
}

@JsonSerializable(createToJson: false)
class PaymentSummary {
  const PaymentSummary({
    required this.id,
    this.status = '',
    this.amountPaise = 0,
    this.refundedPaise = 0,
    this.method,
    this.capturedAt,
    this.failureReason,
  });
  final String id;
  final String status;
  final int amountPaise;
  final int refundedPaise;
  final String? method;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? capturedAt;
  final String? failureReason;
  factory PaymentSummary.fromJson(Map<String, dynamic> json) => _$PaymentSummaryFromJson(json);
}

@JsonSerializable(createToJson: false)
class RefundSummary {
  const RefundSummary({this.amountPaise = 0, this.status = '', this.reason});
  final int amountPaise;
  final String status;
  final String? reason;
  factory RefundSummary.fromJson(Map<String, dynamic> json) => _$RefundSummaryFromJson(json);

  bool get isSettled => status.toUpperCase() == 'SUCCEEDED' || status.toUpperCase() == 'PROCESSED';
}

@JsonSerializable(createToJson: false)
class RefundTier {
  const RefundTier({required this.until, this.refundPercent = 0});
  final String until;
  final int refundPercent;
  factory RefundTier.fromJson(Map<String, dynamic> json) => _$RefundTierFromJson(json);
  DateTime? get untilDate => DateTime.tryParse(until)?.toLocal();
}

/// What cancelling right now would do (guest view only).
@JsonSerializable(createToJson: false)
class CancellationState {
  const CancellationState({this.summary = '', this.tiers = const [], this.freeCancellationUntil, this.refundPercentNow = 0, this.refundPaiseNow = 0});
  final String summary;
  @JsonKey(defaultValue: <RefundTier>[])
  final List<RefundTier> tiers;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? freeCancellationUntil;
  final int refundPercentNow;
  final int refundPaiseNow;
  factory CancellationState.fromJson(Map<String, dynamic> json) => _$CancellationStateFromJson(json);
}

@JsonSerializable(createToJson: false)
class TimelineEvent {
  const TimelineEvent({required this.status, required this.at, this.actorRole, this.reason});
  @JsonKey(unknownEnumValue: BookingStatus.unknown)
  final BookingStatus status;
  final DateTime at;
  final String? actorRole;
  final String? reason;
  factory TimelineEvent.fromJson(Map<String, dynamic> json) => _$TimelineEventFromJson(json);
}

/// Who booked, as the host sees them. Contact details appear once the booking is confirmed.
@JsonSerializable(createToJson: false)
class GuestContact {
  const GuestContact({this.id, this.name, this.email, this.phone});
  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  factory GuestContact.fromJson(Map<String, dynamic> json) => _$GuestContactFromJson(json);
}

@JsonSerializable(createToJson: false)
class OwnerShare {
  const OwnerShare({this.commissionPaise = 0, this.ownerNetPaise = 0});
  final int commissionPaise;
  final int ownerNetPaise;
  factory OwnerShare.fromJson(Map<String, dynamic> json) => _$OwnerShareFromJson(json);
}

@JsonSerializable(createToJson: false)
class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.status,
    this.viewer = ViewerRole.guest,
    required this.checkIn,
    required this.checkOut,
    this.nights = 1,
    this.guestsCount = 1,
    this.currency = 'INR',
    required this.hostel,
    this.items = const [],
    this.guests = const [],
    this.contactPhone,
    this.specialRequests,
    this.pricing = const BookingPricing(),
    this.bookingMode = BookingMode.instant,
    this.cancellationPolicy = CancellationPolicy.unknown,
    this.holdExpiresAt,
    this.approvalDeadline,
    this.confirmedAt,
    this.checkedInAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.cancelledBy,
    this.payment,
    this.refund,
    this.cancellation,
    this.timeline = const [],
    this.actions = const [],
    this.reviewId,
    this.guest,
    this.ownerShare,
    required this.createdAt,
  });

  final String id;
  final String code;
  @JsonKey(unknownEnumValue: BookingStatus.unknown)
  final BookingStatus status;
  @JsonKey(unknownEnumValue: ViewerRole.unknown)
  final ViewerRole viewer;
  @JsonKey(fromJson: parseDate)
  final DateTime checkIn;
  @JsonKey(fromJson: parseDate)
  final DateTime checkOut;
  final int nights;
  final int guestsCount;
  final String currency;
  final BookingHostel hostel;
  @JsonKey(defaultValue: <BookingItem>[])
  final List<BookingItem> items;
  @JsonKey(defaultValue: <BookingGuest>[])
  final List<BookingGuest> guests;
  final String? contactPhone;
  final String? specialRequests;
  final BookingPricing pricing;
  @JsonKey(unknownEnumValue: BookingMode.unknown)
  final BookingMode bookingMode;
  @JsonKey(unknownEnumValue: CancellationPolicy.unknown)
  final CancellationPolicy cancellationPolicy;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? holdExpiresAt;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? approvalDeadline;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? confirmedAt;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? checkedInAt;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? completedAt;
  @JsonKey(fromJson: _tryDateTime)
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledBy;
  final PaymentSummary? payment;
  final RefundSummary? refund;
  final CancellationState? cancellation;
  @JsonKey(defaultValue: <TimelineEvent>[])
  final List<TimelineEvent> timeline;
  @JsonKey(defaultValue: <BookingAction>[], unknownEnumValue: BookingAction.unknown)
  final List<BookingAction> actions;
  final String? reviewId;
  final GuestContact? guest;
  final OwnerShare? ownerShare;
  final DateTime createdAt;

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

  bool can(BookingAction a) => actions.contains(a);
}
