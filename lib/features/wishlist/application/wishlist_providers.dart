import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../../hostels/domain/hostel_models.dart';

/// Ids of everything the signed-in user saved, so hearts can be drawn on cached public lists. Empty when signed out.
final wishlistIdsProvider = AsyncNotifierProvider<WishlistIdsNotifier, Set<String>>(WishlistIdsNotifier.new);

class WishlistIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (ref.watch(userIdProvider) == null) return <String>{};
    return ref.read(wishlistRepositoryProvider).ids();
  }

  bool isSaved(String id) => state.value?.contains(id) ?? false;

  final _inFlight = <String>{};

  /// Optimistic: the heart flips immediately and is put back if the server refuses. Returns the new saved state.
  /// A second tap on the same heart while the first is still being saved is ignored (two rollbacks would fight each other).
  Future<bool> toggle(String hostelId) async {
    if (!_inFlight.add(hostelId)) return isSaved(hostelId);
    final before = state.value ?? <String>{};
    final saving = !before.contains(hostelId);
    state = AsyncData(saving ? {...before, hostelId} : ({...before}..remove(hostelId)));
    try {
      final repo = ref.read(wishlistRepositoryProvider);
      if (saving) {
        await repo.add(hostelId);
      } else {
        await repo.remove(hostelId);
        ref.read(wishlistListProvider.notifier).edit((items) => items.where((e) => e.hostel.id != hostelId).toList());
      }
      if (saving) ref.invalidate(wishlistListProvider);
      return saving;
    } catch (_) {
      state = AsyncData(before);
      ref.invalidate(wishlistListProvider); // the Saved list may have been edited: reload it rather than guess
      rethrow;
    } finally {
      _inFlight.remove(hostelId);
    }
  }
}

final wishlistListProvider = AsyncNotifierProvider<WishlistListNotifier, PageState<WishlistEntry>>(WishlistListNotifier.new);

class WishlistListNotifier extends PagedNotifier<WishlistEntry> {
  @override
  Future<PageState<WishlistEntry>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<WishlistEntry>> fetch(String? cursor) => ref.read(wishlistRepositoryProvider).list(cursor: cursor);
}
