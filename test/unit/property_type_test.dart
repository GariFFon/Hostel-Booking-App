import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/features/hostels/domain/enums.dart';
import 'package:hostel_booking_app/features/hostels/domain/hostel_models.dart';

void main() {
  test('hostels and PGs are long-term, hotels are nightly', () {
    expect(PropertyType.hostel.isLongTerm, isTrue);
    expect(PropertyType.pg.isLongTerm, isTrue);
    expect(PropertyType.hotel.isLongTerm, isFalse);
    expect(PropertyType.unknown.isLongTerm, isFalse); // an unknown type keeps the nightly flow, which the server will still guard
  });

  test('HOTEL parses, and a future type falls back to a neutral label', () {
    expect(PropertyType.hotel.label, 'Hotel');
    expect(PropertyType.values.map((e) => e.name), containsAll(['hostel', 'pg', 'hotel', 'unknown']));
  });

  test('the backend value decodes, and an unknown one never crashes', () {
    Map<String, dynamic> marker(String type) => {'id': 'h1', 'slug': 's', 'name': 'N', 'propertyType': type, 'latitude': 15.0, 'longitude': 74.0};
    expect(MapMarker.fromJson(marker('HOTEL')).propertyType, PropertyType.hotel);
    expect(MapMarker.fromJson(marker('CASTLE')).propertyType, PropertyType.unknown);
  });
}
