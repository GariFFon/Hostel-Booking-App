import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/envelope.dart';

/// Accumulated keyset pages. [moreError] is a failure while loading the *next* page (the first page's failure is the AsyncValue's error).
@immutable
class PageState<T> {
  const PageState({this.items = const [], this.nextCursor, this.total, this.loadingMore = false, this.moreError});

  final List<T> items;
  final String? nextCursor;
  final int? total;
  final bool loadingMore;
  final Object? moreError;

  bool get hasMore => nextCursor != null;
  bool get isEmpty => items.isEmpty;

  PageState<T> copyWith({List<T>? items, bool? loadingMore, Object? moreError, bool clearError = false}) => PageState<T>(
    items: items ?? this.items,
    nextCursor: nextCursor,
    total: total,
    loadingMore: loadingMore ?? this.loadingMore,
    moreError: clearError ? null : (moreError ?? this.moreError),
  );
}

/// Base for every cursor-paginated list: first page on build, [loadMore] for the rest, `ref.invalidate` to refresh.
/// A cursor is only valid for the filters it came from, so filters must be read in `build` (a change rebuilds from page one).
abstract class PagedNotifier<T> extends AsyncNotifier<PageState<T>> {
  Future<Paged<T>> fetch(String? cursor);

  @override
  Future<PageState<T>> build() async {
    final page = await fetch(null);
    return PageState<T>(items: page.items, nextCursor: page.nextCursor, total: page.total);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await fetch(current.nextCursor);
      if (!ref.mounted) return;
      // Merge into whatever the state is *now*: edits made while the page loaded (a removed card, a read notification) must survive.
      // If the list was rebuilt meanwhile (new filter, sign-out) it is no longer "loading more from this cursor": drop the late page.
      final latest = state.value;
      if (latest == null || !latest.loadingMore || latest.nextCursor != current.nextCursor) return;
      state = AsyncData(PageState<T>(items: [...latest.items, ...page.items], nextCursor: page.nextCursor, total: latest.total ?? page.total));
    } catch (e) {
      if (!ref.mounted) return;
      final latest = state.value;
      if (latest == null || !latest.loadingMore || latest.nextCursor != current.nextCursor) return;
      state = AsyncData(latest.copyWith(loadingMore: false, moreError: e));
    }
  }

  /// Local edit of the loaded items (remove a card, mark a row read) without refetching.
  void edit(List<T> Function(List<T> items) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: change(current.items)));
  }
}
