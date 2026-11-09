import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../data/search_params.dart';
import '../domain/hostel_models.dart';

/// The search the Explore screen is showing. Changing it restarts the result list from page one.
final searchParamsProvider = NotifierProvider<SearchParamsNotifier, SearchParams>(SearchParamsNotifier.new);

class SearchParamsNotifier extends Notifier<SearchParams> {
  @override
  SearchParams build() => const SearchParams();

  void set(SearchParams p) => state = p;
  void update(SearchParams Function(SearchParams current) change) => state = change(state);
}

final searchResultsProvider = AsyncNotifierProvider<SearchResultsNotifier, PageState<HostelCard>>(SearchResultsNotifier.new);

class SearchResultsNotifier extends PagedNotifier<HostelCard> {
  late SearchParams _params;

  @override
  Future<PageState<HostelCard>> build() {
    _params = ref.watch(searchParamsProvider);
    return super.build();
  }

  @override
  Future<Paged<HostelCard>> fetch(String? cursor) => ref.read(hostelRepositoryProvider).search(_params, cursor: cursor);
}

final hostelDetailProvider =
    FutureProvider.autoDispose.family<HostelDetail, String>((ref, slug) => ref.watch(hostelRepositoryProvider).detail(slug));

@immutable
class AvailabilityArgs {
  const AvailabilityArgs(this.slug, this.checkIn, this.checkOut, this.guests);
  final String slug;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityArgs && other.slug == slug && other.checkIn == checkIn && other.checkOut == checkOut && other.guests == guests;

  @override
  int get hashCode => Object.hash(slug, checkIn, checkOut, guests);
}

final availabilityProvider = FutureProvider.autoDispose.family<Availability, AvailabilityArgs>(
  (ref, a) => ref.watch(hostelRepositoryProvider).availability(a.slug, checkIn: a.checkIn, checkOut: a.checkOut, guests: a.guests),
);

final offersProvider =
    FutureProvider.autoDispose.family<List<Offer>, String>((ref, slug) => ref.watch(hostelRepositoryProvider).offers(slug));

final amenitiesProvider = FutureProvider<List<Amenity>>((ref) => ref.watch(hostelRepositoryProvider).amenities());

final citiesProvider = FutureProvider<List<CityStat>>((ref) => ref.watch(hostelRepositoryProvider).cities());

/// Autocomplete. The UI debounces; this only fetches for a settled query.
final suggestionsProvider = FutureProvider.autoDispose.family<Suggestions, String>((ref, q) async {
  if (q.trim().length < 2) return const Suggestions();
  return ref.watch(hostelRepositoryProvider).suggest(q.trim());
});

@immutable
class MapQuery {
  const MapQuery(this.params, this.bbox);
  final SearchParams params;
  final String bbox;

  @override
  bool operator ==(Object other) => other is MapQuery && other.params == params && other.bbox == bbox;

  @override
  int get hashCode => Object.hash(params, bbox);
}

final mapMarkersProvider = FutureProvider.autoDispose.family<List<MapMarker>, MapQuery>(
  (ref, q) => ref.watch(hostelRepositoryProvider).mapMarkers(q.params, bbox: q.bbox),
);

/// A search for a stay needs both dates; helper for UI that formats "12–15 Mar · 2 guests".
String stayLabel(SearchParams p) {
  final parts = <String>[
    if (p.hasDates) fmtRange(p.checkIn!, p.checkOut!),
    if (p.guests > 1 || p.hasDates) plural(p.guests, 'guest'),
  ];
  return parts.isEmpty ? 'Any dates' : parts.join(' · ');
}
