import 'package:json_annotation/json_annotation.dart';

import '../../hostels/domain/enums.dart';

part 'host_models.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ListingStatus {
  draft('Draft'),
  pendingReview('In review'),
  approved('Live'),
  rejected('Needs changes'),
  suspended('Suspended'),
  unknown('Unknown');

  const ListingStatus(this.label);
  final String label;
}

@JsonSerializable(createToJson: false)
class OwnerHostel {
  const OwnerHostel({
    required this.id,
    required this.slug,
    required this.name,
    this.city = '',
    this.propertyType = PropertyType.unknown,
    this.status = ListingStatus.unknown,
    this.coverUrl,
    this.roomTypeCount = 0,
    this.mediaCount = 0,
    this.minPricePaise,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.rejectionReason,
    required this.updatedAt,
  });

  final String id;
  final String slug;
  final String name;
  final String city;
  @JsonKey(unknownEnumValue: PropertyType.unknown)
  final PropertyType propertyType;
  @JsonKey(unknownEnumValue: ListingStatus.unknown)
  final ListingStatus status;
  final String? coverUrl;
  final int roomTypeCount;
  final int mediaCount;
  final int? minPricePaise;
  final double avgRating;
  final int reviewCount;
  final String? rejectionReason;
  final DateTime updatedAt;

  factory OwnerHostel.fromJson(Map<String, dynamic> json) => _$OwnerHostelFromJson(json);
}

@JsonSerializable(createToJson: false)
class SettledEarnings {
  const SettledEarnings({this.bookings = 0, this.ownerPayablePaise = 0, this.commissionPaise = 0, this.taxPaise = 0, this.refundedPaise = 0});
  final int bookings;
  final int ownerPayablePaise;
  final int commissionPaise;
  final int taxPaise;
  final int refundedPaise;
  factory SettledEarnings.fromJson(Map<String, dynamic> json) => _$SettledEarningsFromJson(json);
}

@JsonSerializable(createToJson: false)
class UpcomingEarnings {
  const UpcomingEarnings({this.bookings = 0, this.expectedOwnerPaise = 0});
  final int bookings;
  final int expectedOwnerPaise;
  factory UpcomingEarnings.fromJson(Map<String, dynamic> json) => _$UpcomingEarningsFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostelEarnings {
  const HostelEarnings({required this.hostelId, required this.name, this.bookings = 0, this.ownerPayablePaise = 0});
  final String hostelId;
  final String name;
  final int bookings;
  final int ownerPayablePaise;
  factory HostelEarnings.fromJson(Map<String, dynamic> json) => _$HostelEarningsFromJson(json);
}

@JsonSerializable(createToJson: false)
class Earnings {
  const Earnings({
    this.from = '',
    this.to = '',
    this.currency = 'INR',
    this.settled = const SettledEarnings(),
    this.upcoming = const UpcomingEarnings(),
    this.byHostel = const [],
  });
  final String from;
  final String to;
  final String currency;
  final SettledEarnings settled;
  final UpcomingEarnings upcoming;
  @JsonKey(defaultValue: <HostelEarnings>[])
  final List<HostelEarnings> byHostel;
  factory Earnings.fromJson(Map<String, dynamic> json) => _$EarningsFromJson(json);
}
