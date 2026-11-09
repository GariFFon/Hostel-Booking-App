// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hostel_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoPoint _$GeoPointFromJson(Map<String, dynamic> json) => GeoPoint(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

HostelCard _$HostelCardFromJson(Map<String, dynamic> json) => HostelCard(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  propertyType:
      $enumDecodeNullable(
        _$PropertyTypeEnumMap,
        json['propertyType'],
        unknownValue: PropertyType.unknown,
      ) ??
      PropertyType.unknown,
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  locality: json['locality'] as String?,
  location: json['location'] == null
      ? null
      : GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  coverUrl: json['coverUrl'] as String?,
  photoUrls:
      (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  amenityCodes:
      (json['amenityCodes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  roomKinds:
      (json['roomKinds'] as List<dynamic>?)
          ?.map(
            (e) => $enumDecode(
              _$RoomKindEnumMap,
              e,
              unknownValue: RoomKind.unknown,
            ),
          )
          .toList() ??
      [],
  fromPricePaise: (json['fromPricePaise'] as num?)?.toInt(),
  stayFromPricePaise: (json['stayFromPricePaise'] as num?)?.toInt(),
  currency: json['currency'] as String? ?? 'INR',
  avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  bookingMode:
      $enumDecodeNullable(
        _$BookingModeEnumMap,
        json['bookingMode'],
        unknownValue: BookingMode.unknown,
      ) ??
      BookingMode.instant,
  genderPolicy:
      $enumDecodeNullable(
        _$GenderPolicyEnumMap,
        json['genderPolicy'],
        unknownValue: GenderPolicy.unknown,
      ) ??
      GenderPolicy.mixed,
  cancellationPolicy:
      $enumDecodeNullable(
        _$CancellationPolicyEnumMap,
        json['cancellationPolicy'],
        unknownValue: CancellationPolicy.unknown,
      ) ??
      CancellationPolicy.unknown,
);

const _$PropertyTypeEnumMap = {
  PropertyType.hostel: 'HOSTEL',
  PropertyType.pg: 'PG',
  PropertyType.unknown: 'UNKNOWN',
};

const _$RoomKindEnumMap = {
  RoomKind.dorm: 'DORM',
  RoomKind.private: 'PRIVATE',
  RoomKind.unknown: 'UNKNOWN',
};

const _$BookingModeEnumMap = {
  BookingMode.instant: 'INSTANT',
  BookingMode.approval: 'APPROVAL',
  BookingMode.unknown: 'UNKNOWN',
};

const _$GenderPolicyEnumMap = {
  GenderPolicy.mixed: 'MIXED',
  GenderPolicy.maleOnly: 'MALE_ONLY',
  GenderPolicy.femaleOnly: 'FEMALE_ONLY',
  GenderPolicy.unknown: 'UNKNOWN',
};

const _$CancellationPolicyEnumMap = {
  CancellationPolicy.flexible: 'FLEXIBLE',
  CancellationPolicy.moderate: 'MODERATE',
  CancellationPolicy.strict: 'STRICT',
  CancellationPolicy.unknown: 'UNKNOWN',
};

WishlistEntry _$WishlistEntryFromJson(Map<String, dynamic> json) =>
    WishlistEntry(
      savedAt: DateTime.parse(json['savedAt'] as String),
      hostel: HostelCard.fromJson(json['hostel'] as Map<String, dynamic>),
    );

MapMarker _$MapMarkerFromJson(Map<String, dynamic> json) => MapMarker(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  propertyType:
      $enumDecodeNullable(
        _$PropertyTypeEnumMap,
        json['propertyType'],
        unknownValue: PropertyType.unknown,
      ) ??
      PropertyType.unknown,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  fromPricePaise: (json['fromPricePaise'] as num?)?.toInt(),
  avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
);

Amenity _$AmenityFromJson(Map<String, dynamic> json) => Amenity(
  code: json['code'] as String,
  label: json['label'] as String,
  category: json['category'] as String? ?? '',
  icon: json['icon'] as String?,
);

HostelMedia _$HostelMediaFromJson(Map<String, dynamic> json) => HostelMedia(
  id: json['id'] as String,
  roomTypeId: json['roomTypeId'] as String?,
  url: json['url'] as String,
  thumbUrl: json['thumbUrl'] as String,
  cardUrl: json['cardUrl'] as String,
  fullUrl: json['fullUrl'] as String,
  altText: json['altText'] as String?,
  width: json['width'] as num?,
  height: json['height'] as num?,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  isCover: json['isCover'] as bool? ?? false,
);

RoomType _$RoomTypeFromJson(Map<String, dynamic> json) => RoomType(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  kind:
      $enumDecodeNullable(
        _$RoomKindEnumMap,
        json['kind'],
        unknownValue: RoomKind.unknown,
      ) ??
      RoomKind.unknown,
  gender:
      $enumDecodeNullable(
        _$RoomGenderEnumMap,
        json['gender'],
        unknownValue: RoomGender.unknown,
      ) ??
      RoomGender.mixed,
  capacity: (json['capacity'] as num?)?.toInt() ?? 1,
  maxOccupancyPerUnit: (json['maxOccupancyPerUnit'] as num?)?.toInt() ?? 1,
  minStayNights: (json['minStayNights'] as num?)?.toInt() ?? 1,
  maxStayNights: (json['maxStayNights'] as num?)?.toInt() ?? 90,
  priceUnit:
      $enumDecodeNullable(
        _$PriceUnitEnumMap,
        json['priceUnit'],
        unknownValue: PriceUnit.unknown,
      ) ??
      PriceUnit.night,
  fromPricePaise: (json['fromPricePaise'] as num?)?.toInt() ?? 0,
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => HostelMedia.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

const _$RoomGenderEnumMap = {
  RoomGender.mixed: 'MIXED',
  RoomGender.male: 'MALE',
  RoomGender.female: 'FEMALE',
  RoomGender.unknown: 'UNKNOWN',
};

const _$PriceUnitEnumMap = {
  PriceUnit.night: 'NIGHT',
  PriceUnit.month: 'MONTH',
  PriceUnit.unknown: 'UNKNOWN',
};

HostelAddress _$HostelAddressFromJson(Map<String, dynamic> json) =>
    HostelAddress(
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      country: json['country'] as String? ?? 'IN',
    );

CancellationInfo _$CancellationInfoFromJson(Map<String, dynamic> json) =>
    CancellationInfo(
      policy:
          $enumDecodeNullable(
            _$CancellationPolicyEnumMap,
            json['policy'],
            unknownValue: CancellationPolicy.unknown,
          ) ??
          CancellationPolicy.unknown,
      summary: json['summary'] as String? ?? '',
    );

TaxInfo _$TaxInfoFromJson(Map<String, dynamic> json) => TaxInfo(
  lowBps: (json['lowBps'] as num?)?.toInt() ?? 500,
  highBps: (json['highBps'] as num?)?.toInt() ?? 1800,
  thresholdPaise: (json['thresholdPaise'] as num?)?.toInt() ?? 750000,
  note: json['note'] as String? ?? '',
);

HostInfo _$HostInfoFromJson(Map<String, dynamic> json) =>
    HostInfo(name: json['name'] as String?);

HostelDetail _$HostelDetailFromJson(Map<String, dynamic> json) => HostelDetail(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  propertyType:
      $enumDecodeNullable(
        _$PropertyTypeEnumMap,
        json['propertyType'],
        unknownValue: PropertyType.unknown,
      ) ??
      PropertyType.unknown,
  bookingMode:
      $enumDecodeNullable(
        _$BookingModeEnumMap,
        json['bookingMode'],
        unknownValue: BookingMode.unknown,
      ) ??
      BookingMode.instant,
  genderPolicy:
      $enumDecodeNullable(
        _$GenderPolicyEnumMap,
        json['genderPolicy'],
        unknownValue: GenderPolicy.unknown,
      ) ??
      GenderPolicy.mixed,
  cancellation: json['cancellation'] == null
      ? const CancellationInfo()
      : CancellationInfo.fromJson(json['cancellation'] as Map<String, dynamic>),
  address: json['address'] == null
      ? const HostelAddress()
      : HostelAddress.fromJson(json['address'] as Map<String, dynamic>),
  location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
  checkInTime: json['checkInTime'] as String? ?? '14:00',
  checkOutTime: json['checkOutTime'] as String? ?? '11:00',
  houseRules: json['houseRules'] as String?,
  currency: json['currency'] as String? ?? 'INR',
  timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
  host: json['host'] == null
      ? const HostInfo()
      : HostInfo.fromJson(json['host'] as Map<String, dynamic>),
  amenities:
      (json['amenities'] as List<dynamic>?)
          ?.map((e) => Amenity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => HostelMedia.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  roomTypes:
      (json['roomTypes'] as List<dynamic>?)
          ?.map((e) => RoomType.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  fromPricePaise: (json['fromPricePaise'] as num?)?.toInt(),
  tax: json['tax'] == null
      ? const TaxInfo()
      : TaxInfo.fromJson(json['tax'] as Map<String, dynamic>),
);

RoomAvailability _$RoomAvailabilityFromJson(Map<String, dynamic> json) =>
    RoomAvailability(
      roomTypeId: json['roomTypeId'] as String,
      name: json['name'] as String,
      kind:
          $enumDecodeNullable(
            _$RoomKindEnumMap,
            json['kind'],
            unknownValue: RoomKind.unknown,
          ) ??
          RoomKind.unknown,
      availableUnits: (json['availableUnits'] as num?)?.toInt() ?? 0,
      eligible: json['eligible'] as bool? ?? false,
      reason: json['reason'] as String?,
      avgNightlyPaise: (json['avgNightlyPaise'] as num?)?.toInt(),
      stayPerUnitPaise: (json['stayPerUnitPaise'] as num?)?.toInt(),
    );

Availability _$AvailabilityFromJson(Map<String, dynamic> json) => Availability(
  hostelId: json['hostelId'] as String,
  checkIn: json['checkIn'] as String,
  checkOut: json['checkOut'] as String,
  nights: (json['nights'] as num?)?.toInt() ?? 1,
  guests: (json['guests'] as num?)?.toInt() ?? 1,
  canHost: json['canHost'] as bool? ?? false,
  rooms:
      (json['rooms'] as List<dynamic>?)
          ?.map((e) => RoomAvailability.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

CityStat _$CityStatFromJson(Map<String, dynamic> json) => CityStat(
  city: json['city'] as String,
  state: json['state'] as String? ?? '',
  count: (json['count'] as num?)?.toInt() ?? 0,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  fromPricePaise: (json['fromPricePaise'] as num?)?.toInt(),
);

HostelSuggestion _$HostelSuggestionFromJson(Map<String, dynamic> json) =>
    HostelSuggestion(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
    );

Suggestions _$SuggestionsFromJson(Map<String, dynamic> json) => Suggestions(
  cities:
      (json['cities'] as List<dynamic>?)
          ?.map((e) => CityStat.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  hostels:
      (json['hostels'] as List<dynamic>?)
          ?.map((e) => HostelSuggestion.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Offer _$OfferFromJson(Map<String, dynamic> json) => Offer(
  code: json['code'] as String,
  description: json['description'] as String?,
  headline: json['headline'] as String,
  minBookingPaise: (json['minBookingPaise'] as num?)?.toInt() ?? 0,
  scope: json['scope'] as String? ?? 'PROPERTY',
  validTo: json['validTo'] == null
      ? null
      : DateTime.parse(json['validTo'] as String),
);
