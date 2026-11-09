import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/format.dart';
import '../../hostels/domain/enums.dart';
import 'booking_models.dart';

part 'quote_models.g.dart';

@JsonSerializable(createToJson: false)
class QuoteItem {
  const QuoteItem({
    required this.roomTypeId,
    required this.name,
    this.kind = RoomKind.unknown,
    this.units = 1,
    this.nightly = const [],
    this.lineSubtotalPaise = 0,
  });
  final String roomTypeId;
  final String name;
  @JsonKey(unknownEnumValue: RoomKind.unknown)
  final RoomKind kind;
  final int units;
  @JsonKey(defaultValue: <NightlyPrice>[])
  final List<NightlyPrice> nightly;
  final int lineSubtotalPaise;
  factory QuoteItem.fromJson(Map<String, dynamic> json) => _$QuoteItemFromJson(json);

  bool get hasSpecialPrice => nightly.any((n) => n.isSpecialPrice);
}

/// Either an applied coupon (`valid` with a discount) or a rejected one (`reason` + `message`); the quote is still at full price then.
@JsonSerializable(createToJson: false)
class QuoteCoupon {
  const QuoteCoupon({required this.code, required this.valid, this.discountPaise = 0, this.description, this.reason, this.message});
  final String code;
  final bool valid;
  final int discountPaise;
  final String? description;
  final String? reason;
  final String? message;
  factory QuoteCoupon.fromJson(Map<String, dynamic> json) => _$QuoteCouponFromJson(json);
}

@JsonSerializable(createToJson: false)
class CancellationTerms {
  const CancellationTerms({this.policy = CancellationPolicy.unknown, this.summary = '', this.freeCancellationUntil, this.tiers = const []});
  @JsonKey(unknownEnumValue: CancellationPolicy.unknown)
  final CancellationPolicy policy;
  final String summary;
  final String? freeCancellationUntil;
  @JsonKey(defaultValue: <RefundTier>[])
  final List<RefundTier> tiers;
  factory CancellationTerms.fromJson(Map<String, dynamic> json) => _$CancellationTermsFromJson(json);

  DateTime? get freeUntil => freeCancellationUntil == null ? null : DateTime.tryParse(freeCancellationUntil!)?.toLocal();
}

@JsonSerializable(createToJson: false)
class Quote {
  const Quote({
    required this.hostelId,
    this.hostelName = '',
    this.currency = 'INR',
    required this.checkIn,
    required this.checkOut,
    this.nights = 1,
    this.guests = 1,
    this.items = const [],
    this.subtotalPaise = 0,
    this.discountPaise = 0,
    this.taxPaise = 0,
    this.serviceFeePaise = 0,
    this.totalPaise = 0,
    this.effectiveGstBps = 0,
    this.coupon,
    this.cancellation = const CancellationTerms(),
    this.bookingMode = BookingMode.instant,
    this.holdMinutes = 15,
    this.checkInTime = '14:00',
    this.checkOutTime = '11:00',
  });

  final String hostelId;
  final String hostelName;
  final String currency;
  @JsonKey(fromJson: parseDate)
  final DateTime checkIn;
  @JsonKey(fromJson: parseDate)
  final DateTime checkOut;
  final int nights;
  final int guests;
  @JsonKey(defaultValue: <QuoteItem>[])
  final List<QuoteItem> items;
  final int subtotalPaise;
  final int discountPaise;
  final int taxPaise;
  final int serviceFeePaise;
  final int totalPaise;
  final int effectiveGstBps;
  final QuoteCoupon? coupon;
  final CancellationTerms cancellation;
  @JsonKey(unknownEnumValue: BookingMode.unknown)
  final BookingMode bookingMode;
  final int holdMinutes;
  final String checkInTime;
  final String checkOutTime;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

  bool get isFree => totalPaise == 0;
  bool get couponApplied => coupon?.valid ?? false;
}
