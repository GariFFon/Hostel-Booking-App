import 'package:json_annotation/json_annotation.dart';

part 'review_models.g.dart';

@JsonSerializable(createToJson: false)
class ReviewerName {
  const ReviewerName({this.name = ''});
  final String name;
  factory ReviewerName.fromJson(Map<String, dynamic> json) => _$ReviewerNameFromJson(json);
}

@JsonSerializable(createToJson: false)
class StayInfo {
  const StayInfo({this.month = '', this.nights = 1});
  final String month;
  final int nights;
  factory StayInfo.fromJson(Map<String, dynamic> json) => _$StayInfoFromJson(json);
}

@JsonSerializable(createToJson: false)
class ReviewHostel {
  const ReviewHostel({required this.id, required this.slug, required this.name});
  final String id;
  final String slug;
  final String name;
  factory ReviewHostel.fromJson(Map<String, dynamic> json) => _$ReviewHostelFromJson(json);
}

/// One review. The public list fills the first block; "my reviews" and the host's list add the rest.
@JsonSerializable(createToJson: false)
class Review {
  const Review({
    required this.id,
    required this.overall,
    this.cleanliness,
    this.location,
    this.staff,
    this.valueForMoney,
    this.title,
    this.comment,
    this.reviewer = const ReviewerName(),
    this.stay = const StayInfo(),
    this.ownerReply,
    this.ownerRepliedAt,
    required this.createdAt,
    this.editedAt,
    this.bookingId,
    this.bookingCode,
    this.status,
    this.moderationReason,
    this.hostel,
    this.editable = false,
    this.editableUntil,
  });

  final String id;
  final int overall;
  final int? cleanliness;
  final int? location;
  final int? staff;
  final int? valueForMoney;
  final String? title;
  final String? comment;
  final ReviewerName reviewer;
  final StayInfo stay;
  final String? ownerReply;
  final String? ownerRepliedAt;
  final DateTime createdAt;
  final String? editedAt;
  final String? bookingId;
  final String? bookingCode;

  /// PUBLISHED | HIDDEN (only on "my reviews" and the host list).
  final String? status;
  final String? moderationReason;
  final ReviewHostel? hostel;
  final bool editable;
  final String? editableUntil;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);

  bool get isHidden => status == 'HIDDEN';
  DateTime? get editableUntilDate => editableUntil == null ? null : DateTime.tryParse(editableUntil!)?.toLocal();
}

@JsonSerializable(createToJson: false)
class ReviewCategories {
  const ReviewCategories({this.cleanliness, this.location, this.staff, this.valueForMoney});
  final double? cleanliness;
  final double? location;
  final double? staff;
  final double? valueForMoney;
  factory ReviewCategories.fromJson(Map<String, dynamic> json) => _$ReviewCategoriesFromJson(json);
}

@JsonSerializable(createToJson: false)
class ReviewSummary {
  const ReviewSummary({this.avgRating = 0, this.reviewCount = 0, this.distribution = const {}, this.categories = const ReviewCategories()});
  final double avgRating;
  final int reviewCount;
  @JsonKey(defaultValue: <String, int>{})
  final Map<String, int> distribution;
  final ReviewCategories categories;
  factory ReviewSummary.fromJson(Map<String, dynamic> json) => _$ReviewSummaryFromJson(json);

  int starCount(int stars) => distribution['$stars'] ?? 0;
}
