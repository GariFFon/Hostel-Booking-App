import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'hostel_models.g.dart';

@JsonSerializable(createToJson: false)
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
  factory GeoPoint.fromJson(Map<String, dynamic> json) => _$GeoPointFromJson(json);
}

/// One search result / wishlist card.
@JsonSerializable(createToJson: false)
class HostelCard {
  const HostelCard({
    required this.id,
    required this.slug,
    required this.name,
    this.propertyType = PropertyType.unknown,
    this.city = '',
    this.state = '',
    this.locality,
    this.location,
    this.distanceKm,
    this.coverUrl,
    this.photoUrls = const [],
    this.amenityCodes = const [],
    this.roomKinds = const [],
    this.fromPricePaise,
    this.stayFromPricePaise,
    this.currency = 'INR',
    this.avgRating = 0,
    this.reviewCount = 0,
    this.bookingMode = BookingMode.instant,
    this.genderPolicy = GenderPolicy.mixed,
    this.cancellationPolicy = CancellationPolicy.unknown,
  });

  final String id;
  final String slug;
  final String name;
  @JsonKey(unknownEnumValue: PropertyType.unknown)
  final PropertyType propertyType;
  final String city;
  final String state;
  final String? locality;
  final GeoPoint? location;
  final double? distanceKm;
  final String? coverUrl;
  @JsonKey(defaultValue: <String>[])
  final List<String> photoUrls;
  @JsonKey(defaultValue: <String>[])
  final List<String> amenityCodes;
  @JsonKey(defaultValue: <RoomKind>[], unknownEnumValue: RoomKind.unknown)
  final List<RoomKind> roomKinds;
  final int? fromPricePaise;

  /// Real average nightly price for the searched dates (price rules included); null without dates.
  final int? stayFromPricePaise;
  final String currency;
  final double avgRating;
  final int reviewCount;
  @JsonKey(unknownEnumValue: BookingMode.unknown)
  final BookingMode bookingMode;
  @JsonKey(unknownEnumValue: GenderPolicy.unknown)
  final GenderPolicy genderPolicy;
  @JsonKey(unknownEnumValue: CancellationPolicy.unknown)
  final CancellationPolicy cancellationPolicy;

  factory HostelCard.fromJson(Map<String, dynamic> json) => _$HostelCardFromJson(json);

  int? get shownPricePaise => stayFromPricePaise ?? fromPricePaise;

  String get place => [if (locality != null && locality!.isNotEmpty) locality!, city].where((s) => s.isNotEmpty).join(', ');

  /// Photos for the card carousel: the gallery when present, else just the cover.
  List<String> get images => photoUrls.isNotEmpty ? photoUrls : [?coverUrl];
}

/// Wishlist entries come with a slimmer hostel object; this maps it onto [HostelCard].
@JsonSerializable(createToJson: false)
class WishlistEntry {
  const WishlistEntry({required this.savedAt, required this.hostel});
  final DateTime savedAt;
  final HostelCard hostel;
  factory WishlistEntry.fromJson(Map<String, dynamic> json) => _$WishlistEntryFromJson(json);
}

@JsonSerializable(createToJson: false)
class MapMarker {
  const MapMarker({
    required this.id,
    required this.slug,
    required this.name,
    this.propertyType = PropertyType.unknown,
    required this.latitude,
    required this.longitude,
    this.fromPricePaise,
    this.avgRating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String slug;
  final String name;
  @JsonKey(unknownEnumValue: PropertyType.unknown)
  final PropertyType propertyType;
  final double latitude;
  final double longitude;
  final int? fromPricePaise;
  final double avgRating;
  final int reviewCount;

  factory MapMarker.fromJson(Map<String, dynamic> json) => _$MapMarkerFromJson(json);
}

@JsonSerializable(createToJson: false)
class Amenity {
  const Amenity({required this.code, required this.label, this.category = '', this.icon});
  final String code;
  final String label;
  final String category;
  final String? icon;
  factory Amenity.fromJson(Map<String, dynamic> json) => _$AmenityFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostelMedia {
  const HostelMedia({
    required this.id,
    this.roomTypeId,
    required this.url,
    required this.thumbUrl,
    required this.cardUrl,
    required this.fullUrl,
    this.altText,
    this.width,
    this.height,
    this.sortOrder = 0,
    this.isCover = false,
  });
  final String id;
  final String? roomTypeId;
  final String url;
  final String thumbUrl;
  final String cardUrl;
  final String fullUrl;
  final String? altText;
  final num? width;
  final num? height;
  final int sortOrder;
  final bool isCover;
  factory HostelMedia.fromJson(Map<String, dynamic> json) => _$HostelMediaFromJson(json);
}

@JsonSerializable(createToJson: false)
class RoomType {
  const RoomType({
    required this.id,
    required this.name,
    this.description,
    this.kind = RoomKind.unknown,
    this.gender = RoomGender.mixed,
    this.capacity = 1,
    this.maxOccupancyPerUnit = 1,
    this.minStayNights = 1,
    this.maxStayNights = 90,
    this.priceUnit = PriceUnit.night,
    this.fromPricePaise = 0,
    this.media = const [],
  });

  final String id;
  final String name;
  final String? description;
  @JsonKey(unknownEnumValue: RoomKind.unknown)
  final RoomKind kind;
  @JsonKey(unknownEnumValue: RoomGender.unknown)
  final RoomGender gender;
  final int capacity;
  final int maxOccupancyPerUnit;
  final int minStayNights;
  final int maxStayNights;
  @JsonKey(unknownEnumValue: PriceUnit.unknown)
  final PriceUnit priceUnit;
  final int fromPricePaise;
  @JsonKey(defaultValue: <HostelMedia>[])
  final List<HostelMedia> media;

  factory RoomType.fromJson(Map<String, dynamic> json) => _$RoomTypeFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostelAddress {
  const HostelAddress({
    this.line1 = '',
    this.line2,
    this.locality,
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = 'IN',
  });
  final String line1;
  final String? line2;
  final String? locality;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  factory HostelAddress.fromJson(Map<String, dynamic> json) => _$HostelAddressFromJson(json);

  String get oneLine => [line1, if (line2 != null && line2!.isNotEmpty) line2!, if (locality != null && locality!.isNotEmpty) locality!, city, state, postalCode]
      .where((s) => s.isNotEmpty)
      .join(', ');
}

@JsonSerializable(createToJson: false)
class CancellationInfo {
  const CancellationInfo({this.policy = CancellationPolicy.unknown, this.summary = ''});
  @JsonKey(unknownEnumValue: CancellationPolicy.unknown)
  final CancellationPolicy policy;
  final String summary;
  factory CancellationInfo.fromJson(Map<String, dynamic> json) => _$CancellationInfoFromJson(json);
}

@JsonSerializable(createToJson: false)
class TaxInfo {
  const TaxInfo({this.lowBps = 500, this.highBps = 1800, this.thresholdPaise = 750000, this.note = ''});
  final int lowBps;
  final int highBps;
  final int thresholdPaise;
  final String note;
  factory TaxInfo.fromJson(Map<String, dynamic> json) => _$TaxInfoFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostInfo {
  const HostInfo({this.name});
  final String? name;
  factory HostInfo.fromJson(Map<String, dynamic> json) => _$HostInfoFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostelDetail {
  const HostelDetail({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.propertyType = PropertyType.unknown,
    this.bookingMode = BookingMode.instant,
    this.genderPolicy = GenderPolicy.mixed,
    this.cancellation = const CancellationInfo(),
    this.address = const HostelAddress(),
    required this.location,
    this.checkInTime = '14:00',
    this.checkOutTime = '11:00',
    this.houseRules,
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.host = const HostInfo(),
    this.amenities = const [],
    this.media = const [],
    this.roomTypes = const [],
    this.avgRating = 0,
    this.reviewCount = 0,
    this.fromPricePaise,
    this.tax = const TaxInfo(),
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  @JsonKey(unknownEnumValue: PropertyType.unknown)
  final PropertyType propertyType;
  @JsonKey(unknownEnumValue: BookingMode.unknown)
  final BookingMode bookingMode;
  @JsonKey(unknownEnumValue: GenderPolicy.unknown)
  final GenderPolicy genderPolicy;
  final CancellationInfo cancellation;
  final HostelAddress address;
  final GeoPoint location;
  final String checkInTime;
  final String checkOutTime;
  final String? houseRules;
  final String currency;
  final String timezone;
  final HostInfo host;
  @JsonKey(defaultValue: <Amenity>[])
  final List<Amenity> amenities;
  @JsonKey(defaultValue: <HostelMedia>[])
  final List<HostelMedia> media;
  @JsonKey(defaultValue: <RoomType>[])
  final List<RoomType> roomTypes;
  final double avgRating;
  final int reviewCount;
  final int? fromPricePaise;
  final TaxInfo tax;

  factory HostelDetail.fromJson(Map<String, dynamic> json) => _$HostelDetailFromJson(json);

  List<HostelMedia> get gallery {
    final sorted = [...media.where((m) => m.roomTypeId == null)]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final cover = sorted.indexWhere((m) => m.isCover);
    if (cover > 0) sorted.insert(0, sorted.removeAt(cover));
    return sorted;
  }

  RoomType? roomById(String id) {
    for (final r in roomTypes) {
      if (r.id == id) return r;
    }
    return null;
  }
}

@JsonSerializable(createToJson: false)
class RoomAvailability {
  const RoomAvailability({
    required this.roomTypeId,
    required this.name,
    this.kind = RoomKind.unknown,
    this.availableUnits = 0,
    this.eligible = false,
    this.reason,
    this.avgNightlyPaise,
    this.stayPerUnitPaise,
  });
  final String roomTypeId;
  final String name;
  @JsonKey(unknownEnumValue: RoomKind.unknown)
  final RoomKind kind;
  final int availableUnits;
  final bool eligible;

  /// MIN_STAY | MAX_STAY | SOLD_OUT when not eligible.
  final String? reason;
  final int? avgNightlyPaise;
  final int? stayPerUnitPaise;
  factory RoomAvailability.fromJson(Map<String, dynamic> json) => _$RoomAvailabilityFromJson(json);
}

@JsonSerializable(createToJson: false)
class Availability {
  const Availability({
    required this.hostelId,
    required this.checkIn,
    required this.checkOut,
    this.nights = 1,
    this.guests = 1,
    this.canHost = false,
    this.rooms = const [],
  });
  final String hostelId;
  final String checkIn;
  final String checkOut;
  final int nights;
  final int guests;
  final bool canHost;
  @JsonKey(defaultValue: <RoomAvailability>[])
  final List<RoomAvailability> rooms;
  factory Availability.fromJson(Map<String, dynamic> json) => _$AvailabilityFromJson(json);

  RoomAvailability? forRoom(String id) {
    for (final r in rooms) {
      if (r.roomTypeId == id) return r;
    }
    return null;
  }
}

@JsonSerializable(createToJson: false)
class CityStat {
  const CityStat({required this.city, this.state = '', this.count = 0, this.latitude, this.longitude, this.fromPricePaise});
  final String city;
  final String state;
  final int count;
  final double? latitude;
  final double? longitude;
  final int? fromPricePaise;
  factory CityStat.fromJson(Map<String, dynamic> json) => _$CityStatFromJson(json);
}

@JsonSerializable(createToJson: false)
class HostelSuggestion {
  const HostelSuggestion({required this.id, required this.slug, required this.name, this.city = ''});
  final String id;
  final String slug;
  final String name;
  final String city;
  factory HostelSuggestion.fromJson(Map<String, dynamic> json) => _$HostelSuggestionFromJson(json);
}

@JsonSerializable(createToJson: false)
class Suggestions {
  const Suggestions({this.cities = const [], this.hostels = const []});
  @JsonKey(defaultValue: <CityStat>[])
  final List<CityStat> cities;
  @JsonKey(defaultValue: <HostelSuggestion>[])
  final List<HostelSuggestion> hostels;
  bool get isEmpty => cities.isEmpty && hostels.isEmpty;
  factory Suggestions.fromJson(Map<String, dynamic> json) => _$SuggestionsFromJson(json);
}

@JsonSerializable(createToJson: false)
class Offer {
  const Offer({
    required this.code,
    this.description,
    required this.headline,
    this.minBookingPaise = 0,
    this.scope = 'PROPERTY',
    this.validTo,
  });
  final String code;
  final String? description;
  final String headline;
  final int minBookingPaise;
  final String scope;
  final DateTime? validTo;
  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);
}
