// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OwnerHostel _$OwnerHostelFromJson(Map<String, dynamic> json) => OwnerHostel(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  city: json['city'] as String? ?? '',
  propertyType:
      $enumDecodeNullable(
        _$PropertyTypeEnumMap,
        json['propertyType'],
        unknownValue: PropertyType.unknown,
      ) ??
      PropertyType.unknown,
  status:
      $enumDecodeNullable(
        _$ListingStatusEnumMap,
        json['status'],
        unknownValue: ListingStatus.unknown,
      ) ??
      ListingStatus.unknown,
  coverUrl: json['coverUrl'] as String?,
  roomTypeCount: (json['roomTypeCount'] as num?)?.toInt() ?? 0,
  mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
  minPricePaise: (json['minPricePaise'] as num?)?.toInt(),
  avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  rejectionReason: json['rejectionReason'] as String?,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

const _$PropertyTypeEnumMap = {
  PropertyType.hostel: 'HOSTEL',
  PropertyType.pg: 'PG',
  PropertyType.unknown: 'UNKNOWN',
};

const _$ListingStatusEnumMap = {
  ListingStatus.draft: 'DRAFT',
  ListingStatus.pendingReview: 'PENDING_REVIEW',
  ListingStatus.approved: 'APPROVED',
  ListingStatus.rejected: 'REJECTED',
  ListingStatus.suspended: 'SUSPENDED',
  ListingStatus.unknown: 'UNKNOWN',
};

SettledEarnings _$SettledEarningsFromJson(Map<String, dynamic> json) =>
    SettledEarnings(
      bookings: (json['bookings'] as num?)?.toInt() ?? 0,
      ownerPayablePaise: (json['ownerPayablePaise'] as num?)?.toInt() ?? 0,
      commissionPaise: (json['commissionPaise'] as num?)?.toInt() ?? 0,
      taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
      refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
    );

UpcomingEarnings _$UpcomingEarningsFromJson(Map<String, dynamic> json) =>
    UpcomingEarnings(
      bookings: (json['bookings'] as num?)?.toInt() ?? 0,
      expectedOwnerPaise: (json['expectedOwnerPaise'] as num?)?.toInt() ?? 0,
    );

HostelEarnings _$HostelEarningsFromJson(Map<String, dynamic> json) =>
    HostelEarnings(
      hostelId: json['hostelId'] as String,
      name: json['name'] as String,
      bookings: (json['bookings'] as num?)?.toInt() ?? 0,
      ownerPayablePaise: (json['ownerPayablePaise'] as num?)?.toInt() ?? 0,
    );

Earnings _$EarningsFromJson(Map<String, dynamic> json) => Earnings(
  from: json['from'] as String? ?? '',
  to: json['to'] as String? ?? '',
  currency: json['currency'] as String? ?? 'INR',
  settled: json['settled'] == null
      ? const SettledEarnings()
      : SettledEarnings.fromJson(json['settled'] as Map<String, dynamic>),
  upcoming: json['upcoming'] == null
      ? const UpcomingEarnings()
      : UpcomingEarnings.fromJson(json['upcoming'] as Map<String, dynamic>),
  byHostel:
      (json['byHostel'] as List<dynamic>?)
          ?.map((e) => HostelEarnings.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);
