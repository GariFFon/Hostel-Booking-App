import 'package:flutter/foundation.dart';

import '../../../core/format/format.dart';
import '../domain/enums.dart';

enum SearchSort {
  recommended('recommended', 'Recommended'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low'),
  rating('rating', 'Top rated'),
  newest('newest', 'Newest'),
  distance('distance', 'Nearest');

  const SearchSort(this.api, this.label);
  final String api;
  final String label;
}

/// Everything a search depends on. Keyset cursors are only valid for the same params, so any change starts a new list.
@immutable
class SearchParams {
  const SearchParams({
    this.q,
    this.city,
    this.checkIn,
    this.checkOut,
    this.guests = 1,
    this.minPricePaise,
    this.maxPricePaise,
    this.amenities = const {},
    this.propertyType,
    this.roomKind,
    this.gender,
    this.minRating,
    this.instantBook = false,
    this.sort = SearchSort.recommended,
  });

  final String? q;
  final String? city;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;
  final int? minPricePaise;
  final int? maxPricePaise;
  final Set<String> amenities;
  final PropertyType? propertyType;
  final RoomKind? roomKind;

  /// `MALE` | `FEMALE` | null (the backend filter takes these two only).
  final String? gender;
  final double? minRating;
  final bool instantBook;
  final SearchSort sort;

  bool get hasDates => checkIn != null && checkOut != null;
  int get nights => hasDates ? nightsBetween(checkIn!, checkOut!) : 0;

  /// What the destination chip shows.
  String? get destination => (city?.isNotEmpty ?? false) ? city : ((q?.isNotEmpty ?? false) ? q : null);

  /// Number of active filters (not counting destination, dates, guests or sort), for the badge on the filter button.
  int get filterCount =>
      (minPricePaise != null || maxPricePaise != null ? 1 : 0) +
      amenities.length +
      (propertyType != null ? 1 : 0) +
      (roomKind != null ? 1 : 0) +
      (gender != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (instantBook ? 1 : 0);

  SearchParams copyWith({
    Object? q = _keep,
    Object? city = _keep,
    Object? checkIn = _keep,
    Object? checkOut = _keep,
    int? guests,
    Object? minPricePaise = _keep,
    Object? maxPricePaise = _keep,
    Set<String>? amenities,
    Object? propertyType = _keep,
    Object? roomKind = _keep,
    Object? gender = _keep,
    Object? minRating = _keep,
    bool? instantBook,
    SearchSort? sort,
  }) {
    return SearchParams(
      q: identical(q, _keep) ? this.q : q as String?,
      city: identical(city, _keep) ? this.city : city as String?,
      checkIn: identical(checkIn, _keep) ? this.checkIn : checkIn as DateTime?,
      checkOut: identical(checkOut, _keep) ? this.checkOut : checkOut as DateTime?,
      guests: guests ?? this.guests,
      minPricePaise: identical(minPricePaise, _keep) ? this.minPricePaise : minPricePaise as int?,
      maxPricePaise: identical(maxPricePaise, _keep) ? this.maxPricePaise : maxPricePaise as int?,
      amenities: amenities ?? this.amenities,
      propertyType: identical(propertyType, _keep) ? this.propertyType : propertyType as PropertyType?,
      roomKind: identical(roomKind, _keep) ? this.roomKind : roomKind as RoomKind?,
      gender: identical(gender, _keep) ? this.gender : gender as String?,
      minRating: identical(minRating, _keep) ? this.minRating : minRating as double?,
      instantBook: instantBook ?? this.instantBook,
      sort: sort ?? this.sort,
    );
  }

  /// Clears every filter but keeps destination, dates, guests and sort.
  SearchParams clearFilters() => SearchParams(q: q, city: city, checkIn: checkIn, checkOut: checkOut, guests: guests, sort: sort);

  Map<String, Object?> toQuery({String? cursor, int limit = 20}) => {
        'q': q,
        'city': city,
        'checkIn': checkIn == null ? null : toApiDate(checkIn!),
        'checkOut': checkOut == null ? null : toApiDate(checkOut!),
        'guests': hasDates || guests > 1 ? guests : null,
        'minPrice': minPricePaise,
        'maxPrice': maxPricePaise,
        'amenities': amenities.isEmpty ? null : (amenities.toList()..sort()),
        'propertyType': propertyType?.name.toUpperCase(),
        'roomKind': roomKind?.name.toUpperCase(),
        'gender': gender,
        'minRating': minRating,
        'instantBook': instantBook ? 'true' : null,
        'sort': sort == SearchSort.recommended ? null : sort.api,
        'limit': limit,
        'cursor': cursor,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchParams &&
      other.q == q &&
      other.city == city &&
      other.checkIn == checkIn &&
      other.checkOut == checkOut &&
      other.guests == guests &&
      other.minPricePaise == minPricePaise &&
      other.maxPricePaise == maxPricePaise &&
      setEquals(other.amenities, amenities) &&
      other.propertyType == propertyType &&
      other.roomKind == roomKind &&
      other.gender == gender &&
      other.minRating == minRating &&
      other.instantBook == instantBook &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(q, city, checkIn, checkOut, guests, minPricePaise, maxPricePaise, Object.hashAllUnordered(amenities), propertyType, roomKind, gender, minRating, instantBook, sort);
}

const Object _keep = Object();
