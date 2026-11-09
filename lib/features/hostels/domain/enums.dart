import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/format.dart';

/// Backend enums. Every one has an `unknown` member so a value added later renders as a neutral label instead of crashing.

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum PropertyType {
  hostel('Hostel'),
  pg('PG'),
  unknown('Stay');

  const PropertyType(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum BookingMode {
  instant,
  approval,
  unknown;

  bool get isInstant => this == BookingMode.instant;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GenderPolicy {
  mixed('Mixed'),
  maleOnly('Men only'),
  femaleOnly('Women only'),
  unknown('Mixed');

  const GenderPolicy(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum CancellationPolicy {
  flexible('Flexible'),
  moderate('Moderate'),
  strict('Strict'),
  unknown('Standard');

  const CancellationPolicy(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum RoomKind {
  dorm('Dorm bed'),
  private('Private room'),
  unknown('Room');

  const RoomKind(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum RoomGender {
  mixed('Mixed'),
  male('Male'),
  female('Female'),
  unknown('Mixed');

  const RoomGender(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum PriceUnit { night, month, unknown }

/// The unit a guest books: a bed in a dorm, a whole room otherwise.
String unitNoun(RoomKind kind, {int n = 1}) => kind == RoomKind.dorm ? (n == 1 ? 'bed' : 'beds') : (n == 1 ? 'room' : 'rooms');

String prettyEnum(Enum e) => humanize(e.name);
