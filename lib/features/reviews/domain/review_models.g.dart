// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewerName _$ReviewerNameFromJson(Map<String, dynamic> json) =>
    ReviewerName(name: json['name'] as String? ?? '');

StayInfo _$StayInfoFromJson(Map<String, dynamic> json) => StayInfo(
  month: json['month'] as String? ?? '',
  nights: (json['nights'] as num?)?.toInt() ?? 1,
);

ReviewHostel _$ReviewHostelFromJson(Map<String, dynamic> json) => ReviewHostel(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
);

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  id: json['id'] as String,
  overall: (json['overall'] as num).toInt(),
  cleanliness: (json['cleanliness'] as num?)?.toInt(),
  location: (json['location'] as num?)?.toInt(),
  staff: (json['staff'] as num?)?.toInt(),
  valueForMoney: (json['valueForMoney'] as num?)?.toInt(),
  title: json['title'] as String?,
  comment: json['comment'] as String?,
  reviewer: json['reviewer'] == null
      ? const ReviewerName()
      : ReviewerName.fromJson(json['reviewer'] as Map<String, dynamic>),
  stay: json['stay'] == null
      ? const StayInfo()
      : StayInfo.fromJson(json['stay'] as Map<String, dynamic>),
  ownerReply: json['ownerReply'] as String?,
  ownerRepliedAt: json['ownerRepliedAt'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  editedAt: json['editedAt'] as String?,
  bookingId: json['bookingId'] as String?,
  bookingCode: json['bookingCode'] as String?,
  status: json['status'] as String?,
  moderationReason: json['moderationReason'] as String?,
  hostel: json['hostel'] == null
      ? null
      : ReviewHostel.fromJson(json['hostel'] as Map<String, dynamic>),
  editable: json['editable'] as bool? ?? false,
  editableUntil: json['editableUntil'] as String?,
);

ReviewCategories _$ReviewCategoriesFromJson(Map<String, dynamic> json) =>
    ReviewCategories(
      cleanliness: (json['cleanliness'] as num?)?.toDouble(),
      location: (json['location'] as num?)?.toDouble(),
      staff: (json['staff'] as num?)?.toDouble(),
      valueForMoney: (json['valueForMoney'] as num?)?.toDouble(),
    );

ReviewSummary _$ReviewSummaryFromJson(Map<String, dynamic> json) =>
    ReviewSummary(
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      distribution:
          (json['distribution'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          {},
      categories: json['categories'] == null
          ? const ReviewCategories()
          : ReviewCategories.fromJson(
              json['categories'] as Map<String, dynamic>,
            ),
    );
