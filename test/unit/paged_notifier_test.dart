import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/paging/paged_notifier.dart';

/// A list whose second page we can hold back, to test what happens to edits and rebuilds while "load more" is in flight.
class _Items extends PagedNotifier<int> {
  static Completer<Paged<int>>? secondPage;
  static var generation = 0;

  @override
  Future<PageState<int>> build() {
    generation++;
    return super.build();
  }

  @override
  Future<Paged<int>> fetch(String? cursor) {
    if (cursor == null) return Future.value(Paged<int>(items: generation == 1 ? [1, 2, 3] : [100, 200], nextCursor: generation == 1 ? 'p2' : 'q2'));
    return secondPage!.future;
  }
}

final _provider = AsyncNotifierProvider<_Items, PageState<int>>(_Items.new);

void main() {
  setUp(() {
    _Items.generation = 0;
    _Items.secondPage = Completer<Paged<int>>();
  });

  test('an edit made while the next page loads is not undone when the page arrives', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(_provider.future);
    final more = c.read(_provider.notifier).loadMore();
    c.read(_provider.notifier).edit((items) => items.where((i) => i != 2).toList()); // e.g. a card removed meanwhile
    _Items.secondPage!.complete(const Paged<int>(items: [4, 5]));
    await more;
    expect(c.read(_provider).value!.items, [1, 3, 4, 5]);
    expect(c.read(_provider).value!.loadingMore, isFalse);
  });

  test('a list rebuilt meanwhile (new filter, sign-out) drops the late page instead of mixing queries', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(_provider.future);
    final more = c.read(_provider.notifier).loadMore();
    c.invalidate(_provider); // the filter changed: starts again from page one
    await c.read(_provider.future);
    _Items.secondPage!.complete(const Paged<int>(items: [4, 5]));
    await more;
    expect(c.read(_provider).value!.items, [100, 200]);
  });
}
