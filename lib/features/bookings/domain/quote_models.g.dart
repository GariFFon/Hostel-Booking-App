// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuoteItem _$QuoteItemFromJson(Map<String, dynamic> json) => QuoteItem(
  roomTypeId: json['roomTypeId'] as String,
  name: json['name'] as String,
  kind: $enumDecodeNullable(_$RoomKindEnumMap, json['kind'], unknownValue: RoomKind.unknown) ?? RoomKind.unknown,
  units: (json['units'] as num?)?.toInt() ?? 1,
  nightly: (json['nightly'] as List<dynamic>?)?.map((e) => NightlyPrice.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  lineSubtotalPaise: (json['lineSubtotalPaise'] as num?)?.toInt() ?? 0,
);

const _$RoomKindEnumMap = {RoomKind.dorm: 'DORM', RoomKind.private: 'PRIVATE', RoomKind.unknown: 'UNKNOWN'};

QuoteCoupon _$QuoteCouponFromJson(Map<String, dynamic> json) => QuoteCoupon(
  code: json['code'] as String,
  valid: json['valid'] as bool,
  discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
  description: json['description'] as String?,
  reason: json['reason'] as String?,
  message: json['message'] as String?,
);

CancellationTerms _$CancellationTermsFromJson(Map<String, dynamic> json) => CancellationTerms(
  policy: $enumDecodeNullable(_$CancellationPolicyEnumMap, json['policy'], unknownValue: CancellationPolicy.unknown) ?? CancellationPolicy.unknown,
  summary: json['summary'] as String? ?? '',
  freeCancellationUntil: json['freeCancellationUntil'] as String?,
  tiers: (json['tiers'] as List<dynamic>?)?.map((e) => RefundTier.fromJson(e as Map<String, dynamic>)).toList() ?? [],
);

const _$CancellationPolicyEnumMap = {
  CancellationPolicy.flexible: 'FLEXIBLE',
  CancellationPolicy.moderate: 'MODERATE',
  CancellationPolicy.strict: 'STRICT',
  CancellationPolicy.unknown: 'UNKNOWN',
};

Quote _$QuoteFromJson(Map<String, dynamic> json) => Quote(
  hostelId: json['hostelId'] as String,
  hostelName: json['hostelName'] as String? ?? '',
  currency: json['currency'] as String? ?? 'INR',
  checkIn: parseDate(json['checkIn'] as String),
  checkOut: parseDate(json['checkOut'] as String),
  nights: (json['nights'] as num?)?.toInt() ?? 1,
  guests: (json['guests'] as num?)?.toInt() ?? 1,
  items: (json['items'] as List<dynamic>?)?.map((e) => QuoteItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  subtotalPaise: (json['subtotalPaise'] as num?)?.toInt() ?? 0,
  discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
  taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
  serviceFeePaise: (json['serviceFeePaise'] as num?)?.toInt() ?? 0,
  totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
  effectiveGstBps: (json['effectiveGstBps'] as num?)?.toInt() ?? 0,
  coupon: json['coupon'] == null ? null : QuoteCoupon.fromJson(json['coupon'] as Map<String, dynamic>),
  cancellation: json['cancellation'] == null ? const CancellationTerms() : CancellationTerms.fromJson(json['cancellation'] as Map<String, dynamic>),
  bookingMode: $enumDecodeNullable(_$BookingModeEnumMap, json['bookingMode'], unknownValue: BookingMode.unknown) ?? BookingMode.instant,
  holdMinutes: (json['holdMinutes'] as num?)?.toInt() ?? 15,
  checkInTime: json['checkInTime'] as String? ?? '14:00',
  checkOutTime: json['checkOutTime'] as String? ?? '11:00',
);

const _$BookingModeEnumMap = {BookingMode.instant: 'INSTANT', BookingMode.approval: 'APPROVAL', BookingMode.unknown: 'UNKNOWN'};
