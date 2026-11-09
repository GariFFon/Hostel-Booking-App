import 'package:flutter/material.dart';

/// Backend amenity code -> icon. Unknown codes get a neutral check so a new amenity never renders as a hole.
IconData amenityIcon(String code) {
  return switch (code.toUpperCase()) {
    'WIFI' => Icons.wifi_rounded,
    'AC' => Icons.ac_unit_rounded,
    'LOCKERS' => Icons.lock_outline_rounded,
    'LAUNDRY' => Icons.local_laundry_service_outlined,
    'BREAKFAST' => Icons.free_breakfast_outlined,
    'KITCHEN' => Icons.kitchen_outlined,
    'CAFE' => Icons.local_cafe_outlined,
    'COWORK' => Icons.laptop_mac_rounded,
    'CCTV' => Icons.videocam_outlined,
    'FEMALE_FLOOR' => Icons.woman_rounded,
    'HOT_WATER' => Icons.hot_tub_outlined,
    'COMMON_ROOM' => Icons.weekend_outlined,
    'ROOFTOP' => Icons.deck_outlined,
    'AIRPORT_PICKUP' => Icons.flight_land_rounded,
    'PARKING' => Icons.local_parking_rounded,
    'TV' => Icons.tv_rounded,
    'GYM' => Icons.fitness_center_rounded,
    'POWER_BACKUP' => Icons.battery_charging_full_rounded,
    'SECURITY' => Icons.shield_outlined,
    'FOOD' => Icons.restaurant_outlined,
    'BIKE_RENTAL' => Icons.pedal_bike_rounded,
    'TOWELS' => Icons.dry_cleaning_outlined,
    _ => Icons.check_circle_outline_rounded,
  };
}
