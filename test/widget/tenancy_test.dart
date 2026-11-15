import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/features/host/application/host_providers.dart';
import 'package:hostel_booking_app/features/host/domain/host_models.dart';
import 'package:hostel_booking_app/features/hostels/domain/enums.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';
import 'package:hostel_booking_app/features/tenancy/presentation/apply_sheet.dart';
import 'package:hostel_booking_app/features/tenancy/presentation/host_tenants_screen.dart';
import 'package:hostel_booking_app/features/tenancy/presentation/my_stay_screen.dart';

import '../support/support.dart';
import '../support/tenancy_support.dart';

const owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Olive Owner', emailVerified: true, roles: [UserRole.guest, UserRole.owner]);

class _FakeHostHostels extends HostHostelsNotifier {
  @override
  Future<Paged<OwnerHostel>> fetch(String? cursor) async => Paged(
    items: [
      OwnerHostel.fromJson({
        'id': 'h1',
        'slug': 'koregaon-pg',
        'name': 'Koregaon Park Students PG',
        'city': 'Pune',
        'propertyType': 'PG',
        'status': 'APPROVED',
        'updatedAt': '2027-01-01T00:00:00Z',
      }),
      OwnerHostel.fromJson({
        'id': 'h2',
        'slug': 'goa-hotel',
        'name': 'Goa Beach Hotel',
        'city': 'Goa',
        'propertyType': 'HOTEL',
        'status': 'APPROVED',
        'updatedAt': '2027-01-01T00:00:00Z',
      }),
    ],
  );
}

List<Override> over(FakeTenancyRepository repo, {AppUser user = guestUser}) => [
  sessionProvider.overrideWith(() => FakeSession(user)),
  tenancyRepositoryProvider.overrideWithValue(repo),
  hostHostelsProvider.overrideWith(_FakeHostHostels.new),
];

void main() {
  setUpAll(initLocale);

  group('My stay', () {
    testWidgets('shows where I live, what is due, and my open request', (t) async {
      final repo = FakeTenancyRepository()
        ..stays = [Tenancy.fromJson(tenancyJson())]
        ..applications = [TenancyApplication.fromJson(applicationJson())];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      expect(find.text('Koregaon Park Students PG'), findsNWidgets(2));
      expect(find.text('Awaiting move-in'), findsOneWidget);
      expect(find.textContaining('₹7,500'), findsOneWidget);
      expect(find.textContaining('Deposit ₹15,000 · due'), findsOneWidget);
      expect(find.textContaining('Pay the deposit to the owner'), findsOneWidget);
      expect(find.text('Open requests'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('withdrawing a request asks the server', (t) async {
      final repo = FakeTenancyRepository()..applications = [TenancyApplication.fromJson(applicationJson())];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('Withdraw'));
      await t.pumpAndSettle();
      expect(repo.calls, ['withdraw']);
    });

    testWidgets('an invitation can be accepted', (t) async {
      final repo = FakeTenancyRepository()
        ..stays = [
          Tenancy.fromJson(tenancyJson(status: 'INVITED', actions: const ['accept', 'decline'])),
        ];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      expect(find.text('Invited'), findsOneWidget);
      await t.tap(find.text('Accept'));
      await t.pumpAndSettle();
      expect(repo.calls, ['accept']);
    });

    testWidgets('has a friendly empty state', (t) async {
      await pumpScreen(t, const MyStayScreen(), overrides: over(FakeTenancyRepository()));
      await t.pumpAndSettle();
      expect(find.text('No stay yet'), findsOneWidget);
    });

    testWidgets('pulling down on the empty screen picks up a stay added meanwhile', (t) async {
      final repo = FakeTenancyRepository();
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      expect(find.text('No stay yet'), findsOneWidget);
      repo.stays = [Tenancy.fromJson(tenancyJson(status: 'INVITED', actions: const ['accept', 'decline']))];
      await t.fling(find.text('No stay yet'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(find.text('Invited'), findsOneWidget);
    });
  });

  group('Requesting a bed', () {
    Future<FakeTenancyRepository> open(WidgetTester t, {GenderPolicy policy = GenderPolicy.mixed, int free = 2}) async {
      final repo = FakeTenancyRepository()..termsData = TenancyTerms.fromJson(termsJson(free: free));
      await pumpScreen(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showApplySheet(context, hostelId: 'h1', hostelName: 'Koregaon PG', genderPolicy: policy),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: over(repo),
        size: const Size(390, 1400),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('lists the rooms with free beds and validates the contact before sending', (t) async {
      final repo = await open(t);
      expect(find.text('Triple sharing'), findsOneWidget);
      expect(find.textContaining('2 free'), findsOneWidget);
      await t.tap(find.text('Send request'));
      await t.pumpAndSettle();
      expect(find.text('Enter a contact name'), findsOneWidget);
      expect(find.textContaining('international format'), findsWidgets);
      expect(repo.calls, isEmpty);
    });

    testWidgets('sends the request once the contact details are valid (spaces and dashes are fine)', (t) async {
      final repo = await open(t);
      await t.enterText(find.byType(TextField).at(2), 'Asha Rao'); // tenure, occupation, contact name, contact phone, message
      await t.enterText(find.byType(TextField).at(3), '+91 98765-43210');
      await t.tap(find.text('Send request'));
      await t.pumpAndSettle();
      expect(repo.calls, ['apply']);
      expect(repo.lastApply, containsPair('phone', '+91 98765-43210')); // the repository strips the formatting before it reaches the API
      expect(repo.lastApply, containsPair('roomTypeId', 'r1'));
    });

    testWidgets('asks for gender on a women-only property', (t) async {
      await open(t, policy: GenderPolicy.femaleOnly);
      expect(find.text('Your gender'), findsOneWidget);
    });

    testWidgets('says so when no bed is free', (t) async {
      await open(t, free: 0);
      expect(find.text('No beds are free right now.'), findsOneWidget);
    });
  });

  group('Host tenants', () {
    testWidgets('approves a request, passing no overrides by default', (t) async {
      final repo = FakeTenancyRepository()
        ..hostRequests = [
          TenancyApplication.fromJson(applicationJson(actions: const ['approve', 'reject'])),
        ];
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1200),
      );
      await t.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.textContaining('MBA student'), findsOneWidget);
      await t.tap(find.text('Approve').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Approve').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['approve']);
      expect(repo.lastApproveRent, isNull);
    });

    testWidgets('declines with a reason the student will read', (t) async {
      final repo = FakeTenancyRepository()
        ..hostRequests = [
          TenancyApplication.fromJson(applicationJson(actions: const ['approve', 'reject'])),
        ];
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1200),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Decline').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Final-year students only');
      await t.tap(find.text('Decline').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['reject']);
      expect(repo.lastReason, 'Final-year students only');
    });

    testWidgets('lets the owner pick the bed when approving', (t) async {
      final repo = FakeTenancyRepository()
        ..hostRequests = [
          TenancyApplication.fromJson(applicationJson(actions: const ['approve', 'reject'])),
        ];
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1400),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Approve').first);
      await t.pumpAndSettle();
      expect(find.text('Assign automatically'), findsOneWidget);
      expect(find.text('B-1 · floor 1'), findsOneWidget);
      await t.tap(find.text('B-2 · floor 1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Approve').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['approve']);
      expect(repo.lastApproveUnit, 'u2');
    });

    testWidgets('adds a tenant by email, with a chosen property, room and bed', (t) async {
      final repo = FakeTenancyRepository();
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Add tenant'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('property')));
      await t.pumpAndSettle();
      expect(find.text('Goa Beach Hotel'), findsNothing); // hotels take nightly bookings, not tenants
      await t.tap(find.text('Koregaon Park Students PG').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('room-h1')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Triple sharing').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('unit-r1')));
      await t.pumpAndSettle();
      await t.tap(find.text('B-2 · floor 1').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'new.tenant@example.com');
      await t.tap(find.text('Add tenant').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['create']);
      expect(repo.lastCreate, containsPair('email', 'new.tenant@example.com'));
      expect(repo.lastCreate, containsPair('roomTypeId', 'r1'));
      expect(repo.lastCreate, containsPair('unitId', 'u2'));
      expect(repo.lastCreate!['method'], isNull);
    });

    testWidgets('asks for a valid email before adding a tenant', (t) async {
      final repo = FakeTenancyRepository();
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Add tenant'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add tenant').last);
      await t.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a guest cannot open the owner screen', (t) async {
      await pumpScreen(t, const HostTenantsScreen(), overrides: over(FakeTenancyRepository()));
      await t.pumpAndSettle();
      expect(find.text('Hosting is not set up'), findsOneWidget);
    });
  });
}
