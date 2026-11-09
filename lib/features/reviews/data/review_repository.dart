import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../domain/review_models.dart';

enum ReviewSort {
  recent('recent', 'Most recent'),
  highest('highest', 'Highest rated'),
  lowest('lowest', 'Lowest rated');

  const ReviewSort(this.api, this.label);
  final String api;
  final String label;
}

/// Ratings for a new or edited review. Null optional categories are simply not sent (create) or cleared (edit).
class ReviewDraft {
  const ReviewDraft({required this.overall, this.cleanliness, this.location, this.staff, this.valueForMoney, this.title, this.comment});
  final int overall;
  final int? cleanliness;
  final int? location;
  final int? staff;
  final int? valueForMoney;
  final String? title;
  final String? comment;

  Map<String, Object?> toCreateJson() => {
        'overall': overall,
        'cleanliness': ?cleanliness,
        'location': ?location,
        'staff': ?staff,
        'valueForMoney': ?valueForMoney,
        if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
        if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
      };

  /// PATCH semantics: `null` clears an optional field.
  Map<String, Object?> toPatchJson() => {
        'overall': overall,
        'cleanliness': cleanliness,
        'location': location,
        'staff': staff,
        'valueForMoney': valueForMoney,
        'title': title == null || title!.trim().isEmpty ? null : title!.trim(),
        'comment': comment == null || comment!.trim().isEmpty ? null : comment!.trim(),
      };
}

class ReviewRepository {
  ReviewRepository(this._api);

  final ApiClient _api;

  Future<Paged<Review>> forHostel(String idOrSlug, {ReviewSort sort = ReviewSort.recent, int? rating, String? cursor}) => _api.getPage(
        '/hostels/$idOrSlug/reviews',
        Review.fromJson,
        query: {'sort': sort.api, 'rating': rating, 'cursor': cursor, 'limit': 10},
        auth: false,
      );

  Future<ReviewSummary> summary(String idOrSlug) => _api.getOne('/hostels/$idOrSlug/reviews/summary', ReviewSummary.fromJson, auth: false);

  Future<Review> create(String bookingId, ReviewDraft d) => _api.postOne('/bookings/$bookingId/review', Review.fromJson, body: d.toCreateJson());

  Future<Paged<Review>> mine({String? cursor}) => _api.getPage('/me/reviews', Review.fromJson, query: {'cursor': cursor, 'limit': 20});

  Future<Review> update(String id, ReviewDraft d) async => Review.fromJson(asMap((await _api.patch('/reviews/$id', body: d.toPatchJson())).data));

  Future<void> delete(String id) => _api.delete('/reviews/$id');
}
