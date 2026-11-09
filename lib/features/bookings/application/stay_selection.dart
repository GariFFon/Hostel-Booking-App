import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../hostels/domain/hostel_models.dart';
import '../data/booking_repository.dart';

/// What the guest has picked on a hostel page: dates, party size and how many beds/rooms of each type.
@immutable
class StaySelection {
  const StaySelection({this.checkIn, this.checkOut, this.guests = 1, this.units = const {}});

  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;

  /// room type id -> number of beds/rooms (only entries > 0).
  final Map<String, int> units;

  bool get hasDates => checkIn != null && checkOut != null;
  int get nights => hasDates ? nightsBetween(checkIn!, checkOut!) : 0;
  int get totalUnits => units.values.fold(0, (a, b) => a + b);
  bool get isEmpty => units.isEmpty;

  List<RoomSelection> get items => [for (final e in units.entries) RoomSelection(e.key, e.value)];

  /// How many people the selected beds/rooms can sleep.
  int capacity(HostelDetail hostel) {
    var total = 0;
    units.forEach((id, n) => total += n * (hostel.roomById(id)?.maxOccupancyPerUnit ?? 1));
    return total;
  }

  StaySelection copyWith({Object? checkIn = _keep, Object? checkOut = _keep, int? guests, Map<String, int>? units}) => StaySelection(
    checkIn: identical(checkIn, _keep) ? this.checkIn : checkIn as DateTime?,
    checkOut: identical(checkOut, _keep) ? this.checkOut : checkOut as DateTime?,
    guests: guests ?? this.guests,
    units: units ?? this.units,
  );

  @override
  bool operator ==(Object other) =>
      other is StaySelection && other.checkIn == checkIn && other.checkOut == checkOut && other.guests == guests && mapEquals(other.units, units);

  @override
  int get hashCode => Object.hash(checkIn, checkOut, guests, Object.hashAllUnordered(units.entries.map((e) => '${e.key}:${e.value}')));
}

const Object _keep = Object();

/// Family key: the hostel plus what the page was opened with (deep link / search context).
typedef StayKey = (String slug, DateTime? checkIn, DateTime? checkOut, int guests);

final staySelectionProvider = NotifierProvider.autoDispose.family<StaySelectionNotifier, StaySelection, StayKey>(StaySelectionNotifier.new);

class StaySelectionNotifier extends Notifier<StaySelection> {
  StaySelectionNotifier(this.key);
  final StayKey key;

  @override
  StaySelection build() => StaySelection(checkIn: key.$2, checkOut: key.$3, guests: key.$4);

  /// New dates change availability, so the picked beds are dropped: they might not exist any more.
  void setDates(DateTime checkIn, DateTime checkOut) => state = state.copyWith(checkIn: checkIn, checkOut: checkOut, units: const {});

  void clearDates() => state = state.copyWith(checkIn: null, checkOut: null, units: const {});

  void setGuests(int guests) => state = state.copyWith(guests: guests);

  void setUnits(String roomTypeId, int n) {
    final next = {...state.units};
    if (n <= 0) {
      next.remove(roomTypeId);
    } else {
      next[roomTypeId] = n;
    }
    state = state.copyWith(units: next);
  }
}
