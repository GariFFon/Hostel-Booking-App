import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/host/data/host_repository.dart';
import 'package:hostel_booking_app/features/host/domain/host_models.dart';
import 'package:hostel_booking_app/features/host/presentation/host_home_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../support/support.dart';

class _MockHostRepo extends Mock implements HostRepository {}

const _owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Meera', roles: [UserRole.owner]);

void main() {
  setUpAll(initLocale);

  testWidgets('dashboard lays out with earnings (regression: stretch inside a scrolling list had infinite height)', (tester) async {
    final repo = _MockHostRepo();
    when(() => repo.bookings(when: any(named: 'when'), status: any(named: 'status'), hostelId: any(named: 'hostelId'), cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Paged.empty<BookingSummary>());
    when(repo.earnings).thenAnswer(
      (_) async => Earnings.fromJson({
        'from': '2026-11-01',
        'to': '2026-11-30',
        'settled': {'bookings': 3, 'ownerPayablePaise': 1234500},
        'upcoming': {'bookings': 2, 'expectedOwnerPaise': 560000},
        'byHostel': [
          {'hostelId': 'h1', 'name': 'The Extraordinarily Long-Named Backpackers Beachfront Hostel ${'Palolem ' * 6}', 'bookings': 5, 'ownerPayablePaise': 1794500},
        ],
      }),
    );
    await pumpScreen(
      tester,
      const HostHomeScreen(),
      overrides: [...baseOverrides(user: _owner), hostRepositoryProvider.overrideWithValue(repo)],
      size: const Size(320, 640),
      textScale: 1.6,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Earned'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('₹12,345'), findsOneWidget);
    expect(find.text('₹5,600'), findsOneWidget);
    expect(find.text('Your listings'), findsOneWidget);
  });

  testWidgets('a guest who reaches a host screen is told hosting is not set up', (tester) async {
    await pumpScreen(tester, const HostHomeScreen(), overrides: baseOverrides());
    expect(find.text('Hosting is not set up'), findsOneWidget);
  });
}
