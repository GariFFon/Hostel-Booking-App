// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingHostelBrief _$BookingHostelBriefFromJson(Map<String, dynamic> json) => BookingHostelBrief(
  id: json['id'] as String,
  name: json['name'] as String,
  city: json['city'] as String? ?? '',
  coverUrl: json['coverUrl'] as String?,
);

BookingSummary _$BookingSummaryFromJson(Map<String, dynamic> json) => BookingSummary(
  id: json['id'] as String,
  code: json['code'] as String,
  status: $enumDecode(_$BookingStatusEnumMap, json['status'], unknownValue: BookingStatus.unknown),
  hostel: BookingHostelBrief.fromJson(json['hostel'] as Map<String, dynamic>),
  checkIn: parseDate(json['checkIn'] as String),
  checkOut: parseDate(json['checkOut'] as String),
  nights: (json['nights'] as num?)?.toInt() ?? 1,
  guestsCount: (json['guestsCount'] as num?)?.toInt() ?? 1,
  totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
  holdExpiresAt: _tryDateTime(json['holdExpiresAt']),
  guestName: json['guestName'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

const _$BookingStatusEnumMap = {
  BookingStatus.hold: 'HOLD',
  BookingStatus.pendingPayment: 'PENDING_PAYMENT',
  BookingStatus.pendingApproval: 'PENDING_APPROVAL',
  BookingStatus.confirmed: 'CONFIRMED',
  BookingStatus.checkedIn: 'CHECKED_IN',
  BookingStatus.completed: 'COMPLETED',
  BookingStatus.expired: 'EXPIRED',
  BookingStatus.cancelledByGuest: 'CANCELLED_BY_GUEST',
  BookingStatus.cancelledByOwner: 'CANCELLED_BY_OWNER',
  BookingStatus.rejected: 'REJECTED',
  BookingStatus.noShow: 'NO_SHOW',
  BookingStatus.unknown: 'UNKNOWN',
};

BookingHostel _$BookingHostelFromJson(Map<String, dynamic> json) => BookingHostel(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  addressLine1: json['addressLine1'] as String? ?? '',
  locality: json['locality'] as String?,
  location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
  coverUrl: json['coverUrl'] as String?,
  checkInTime: json['checkInTime'] as String? ?? '14:00',
  checkOutTime: json['checkOutTime'] as String? ?? '11:00',
  timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
  phone: json['phone'] as String?,
);

NightlyPrice _$NightlyPriceFromJson(Map<String, dynamic> json) => NightlyPrice(
  date: json['date'] as String,
  unitPricePaise: (json['unitPricePaise'] as num?)?.toInt() ?? 0,
  taxBps: (json['taxBps'] as num?)?.toInt() ?? 0,
  isSpecialPrice: json['isSpecialPrice'] as bool? ?? false,
);

BookingItem _$BookingItemFromJson(Map<String, dynamic> json) => BookingItem(
  roomTypeId: json['roomTypeId'] as String?,
  name: json['name'] as String,
  units: (json['units'] as num?)?.toInt() ?? 1,
  lineTotalPaise: (json['lineTotalPaise'] as num?)?.toInt() ?? 0,
  nightly: (json['nightly'] as List<dynamic>?)?.map((e) => NightlyPrice.fromJson(e as Map<String, dynamic>)).toList() ?? [],
);

BookingGuest _$BookingGuestFromJson(Map<String, dynamic> json) => BookingGuest(
  fullName: json['fullName'] as String,
  gender: json['gender'] as String?,
  age: (json['age'] as num?)?.toInt(),
  idType: json['idType'] as String?,
  idLast4: json['idLast4'] as String?,
  isPrimary: json['isPrimary'] as bool? ?? false,
);

BookingPricing _$BookingPricingFromJson(Map<String, dynamic> json) => BookingPricing(
  subtotalPaise: (json['subtotalPaise'] as num?)?.toInt() ?? 0,
  discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
  taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
  serviceFeePaise: (json['serviceFeePaise'] as num?)?.toInt() ?? 0,
  totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
  effectiveGstBps: (json['effectiveGstBps'] as num?)?.toInt() ?? 0,
  couponCode: json['couponCode'] as String?,
);

PaymentSummary _$PaymentSummaryFromJson(Map<String, dynamic> json) => PaymentSummary(
  id: json['id'] as String,
  status: json['status'] as String? ?? '',
  amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
  refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
  method: json['method'] as String?,
  capturedAt: _tryDateTime(json['capturedAt']),
  failureReason: json['failureReason'] as String?,
);

RefundSummary _$RefundSummaryFromJson(Map<String, dynamic> json) => RefundSummary(
  amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? '',
  reason: json['reason'] as String?,
);

RefundTier _$RefundTierFromJson(Map<String, dynamic> json) =>
    RefundTier(until: json['until'] as String, refundPercent: (json['refundPercent'] as num?)?.toInt() ?? 0);

CancellationState _$CancellationStateFromJson(Map<String, dynamic> json) => CancellationState(
  summary: json['summary'] as String? ?? '',
  tiers: (json['tiers'] as List<dynamic>?)?.map((e) => RefundTier.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  freeCancellationUntil: _tryDateTime(json['freeCancellationUntil']),
  refundPercentNow: (json['refundPercentNow'] as num?)?.toInt() ?? 0,
  refundPaiseNow: (json['refundPaiseNow'] as num?)?.toInt() ?? 0,
);

TimelineEvent _$TimelineEventFromJson(Map<String, dynamic> json) => TimelineEvent(
  status: $enumDecode(_$BookingStatusEnumMap, json['status'], unknownValue: BookingStatus.unknown),
  at: DateTime.parse(json['at'] as String),
  actorRole: json['actorRole'] as String?,
  reason: json['reason'] as String?,
);

GuestContact _$GuestContactFromJson(Map<String, dynamic> json) =>
    GuestContact(id: json['id'] as String?, name: json['name'] as String?, email: json['email'] as String?, phone: json['phone'] as String?);

OwnerShare _$OwnerShareFromJson(Map<String, dynamic> json) =>
    OwnerShare(commissionPaise: (json['commissionPaise'] as num?)?.toInt() ?? 0, ownerNetPaise: (json['ownerNetPaise'] as num?)?.toInt() ?? 0);

Booking _$BookingFromJson(Map<String, dynamic> json) => Booking(
  id: json['id'] as String,
  code: json['code'] as String,
  status: $enumDecode(_$BookingStatusEnumMap, json['status'], unknownValue: BookingStatus.unknown),
  viewer: $enumDecodeNullable(_$ViewerRoleEnumMap, json['viewer'], unknownValue: ViewerRole.unknown) ?? ViewerRole.guest,
  checkIn: parseDate(json['checkIn'] as String),
  checkOut: parseDate(json['checkOut'] as String),
  nights: (json['nights'] as num?)?.toInt() ?? 1,
  guestsCount: (json['guestsCount'] as num?)?.toInt() ?? 1,
  currency: json['currency'] as String? ?? 'INR',
  hostel: BookingHostel.fromJson(json['hostel'] as Map<String, dynamic>),
  items: (json['items'] as List<dynamic>?)?.map((e) => BookingItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  guests: (json['guests'] as List<dynamic>?)?.map((e) => BookingGuest.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  contactPhone: json['contactPhone'] as String?,
  specialRequests: json['specialRequests'] as String?,
  pricing: json['pricing'] == null ? const BookingPricing() : BookingPricing.fromJson(json['pricing'] as Map<String, dynamic>),
  bookingMode: $enumDecodeNullable(_$BookingModeEnumMap, json['bookingMode'], unknownValue: BookingMode.unknown) ?? BookingMode.instant,
  cancellationPolicy:
      $enumDecodeNullable(_$CancellationPolicyEnumMap, json['cancellationPolicy'], unknownValue: CancellationPolicy.unknown) ??
      CancellationPolicy.unknown,
  holdExpiresAt: _tryDateTime(json['holdExpiresAt']),
  approvalDeadline: _tryDateTime(json['approvalDeadline']),
  confirmedAt: _tryDateTime(json['confirmedAt']),
  checkedInAt: _tryDateTime(json['checkedInAt']),
  completedAt: _tryDateTime(json['completedAt']),
  cancelledAt: _tryDateTime(json['cancelledAt']),
  cancelReason: json['cancelReason'] as String?,
  cancelledBy: json['cancelledBy'] as String?,
  payment: json['payment'] == null ? null : PaymentSummary.fromJson(json['payment'] as Map<String, dynamic>),
  refund: json['refund'] == null ? null : RefundSummary.fromJson(json['refund'] as Map<String, dynamic>),
  cancellation: json['cancellation'] == null ? null : CancellationState.fromJson(json['cancellation'] as Map<String, dynamic>),
  timeline: (json['timeline'] as List<dynamic>?)?.map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  actions:
      (json['actions'] as List<dynamic>?)?.map((e) => $enumDecode(_$BookingActionEnumMap, e, unknownValue: BookingAction.unknown)).toList() ?? [],
  reviewId: json['reviewId'] as String?,
  guest: json['guest'] == null ? null : GuestContact.fromJson(json['guest'] as Map<String, dynamic>),
  ownerShare: json['ownerShare'] == null ? null : OwnerShare.fromJson(json['ownerShare'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

const _$ViewerRoleEnumMap = {ViewerRole.guest: 'GUEST', ViewerRole.owner: 'OWNER', ViewerRole.admin: 'ADMIN', ViewerRole.unknown: 'UNKNOWN'};

const _$BookingModeEnumMap = {BookingMode.instant: 'INSTANT', BookingMode.approval: 'APPROVAL', BookingMode.unknown: 'UNKNOWN'};

const _$CancellationPolicyEnumMap = {
  CancellationPolicy.flexible: 'FLEXIBLE',
  CancellationPolicy.moderate: 'MODERATE',
  CancellationPolicy.strict: 'STRICT',
  CancellationPolicy.unknown: 'UNKNOWN',
};

const _$BookingActionEnumMap = {
  BookingAction.pay: 'pay',
  BookingAction.cancel: 'cancel',
  BookingAction.approve: 'approve',
  BookingAction.reject: 'reject',
  BookingAction.checkIn: 'check_in',
  BookingAction.complete: 'complete',
  BookingAction.noShow: 'no_show',
  BookingAction.review: 'review',
  BookingAction.unknown: 'unknown',
};
