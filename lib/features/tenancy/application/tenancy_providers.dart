import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/providers.dart';
import '../../auth/application/session.dart';
import '../domain/tenancy_models.dart';

/// What a student sees before asking for a bed: terms and free beds per room type. Public, so it needs no sign-in.
final tenancyTermsProvider = FutureProvider.autoDispose.family<TenancyTerms, String>(
  (ref, idOrSlug) => ref.watch(tenancyRepositoryProvider).terms(idOrSlug),
);

/// The signed-in user's own stays.
final myTenanciesProvider = AsyncNotifierProvider<MyTenanciesNotifier, PageState<Tenancy>>(MyTenanciesNotifier.new);

class MyTenanciesNotifier extends PagedNotifier<Tenancy> {
  @override
  Future<PageState<Tenancy>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<Tenancy>> fetch(String? cursor) => ref.read(tenancyRepositoryProvider).myTenancies(cursor: cursor);
}

/// The signed-in user's requests for a bed.
final myApplicationsProvider = AsyncNotifierProvider<MyApplicationsNotifier, PageState<TenancyApplication>>(MyApplicationsNotifier.new);

class MyApplicationsNotifier extends PagedNotifier<TenancyApplication> {
  @override
  Future<PageState<TenancyApplication>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<TenancyApplication>> fetch(String? cursor) => ref.read(tenancyRepositoryProvider).myApplications(cursor: cursor);
}

/// Beds nobody holds in a room type (owner).
final freeUnitsProvider = FutureProvider.autoDispose.family<List<FreeUnit>, String>(
  (ref, roomTypeId) => ref.watch(tenancyRepositoryProvider).freeUnits(roomTypeId),
);

/// Room types of one of the owner's properties.
final hostRoomsProvider = FutureProvider.autoDispose.family<List<OwnerRoom>, String>(
  (ref, hostelId) => ref.watch(tenancyRepositoryProvider).rooms(hostelId),
);

/// Owner: open requests for beds at their properties.
final hostApplicationsProvider = AsyncNotifierProvider<HostApplicationsNotifier, PageState<TenancyApplication>>(HostApplicationsNotifier.new);

class HostApplicationsNotifier extends PagedNotifier<TenancyApplication> {
  @override
  Future<PageState<TenancyApplication>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<TenancyApplication>> fetch(String? cursor) => ref.read(tenancyRepositoryProvider).hostApplications(cursor: cursor);
}

/// Owner: stays at their properties.
final hostTenanciesProvider = AsyncNotifierProvider<HostTenanciesNotifier, PageState<Tenancy>>(HostTenanciesNotifier.new);

class HostTenanciesNotifier extends PagedNotifier<Tenancy> {
  @override
  Future<PageState<Tenancy>> build() {
    if (ref.watch(userIdProvider) == null) return Future.value(const PageState());
    return super.build();
  }

  @override
  Future<Paged<Tenancy>> fetch(String? cursor) => ref.read(tenancyRepositoryProvider).hostTenancies(cursor: cursor);
}

/// The deposit settlement the owner sent the tenant (404 until it is sent).
final mySettlementProvider = FutureProvider.autoDispose.family<DepositSettlement, String>(
  (ref, tenancyId) => ref.watch(tenancyRepositoryProvider).mySettlement(tenancyId),
);

/// The owner's view of a stay's settlement (a draft is made on first look).
final hostSettlementProvider = FutureProvider.autoDispose.family<DepositSettlement, String>(
  (ref, tenancyId) => ref.watch(tenancyRepositoryProvider).hostSettlement(tenancyId),
);
