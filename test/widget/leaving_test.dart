import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/host/application/host_providers.dart';
import 'package:hostel_booking_app/features/host/domain/host_models.dart';
import 'package:hostel_booking_app/features/rent/domain/rent_models.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';
import 'package:hostel_booking_app/features/tenancy/presentation/host_tenants_screen.dart';
import 'package:hostel_booking_app/features/tenancy/presentation/my_stay_screen.dart';

import '../support/complaint_support.dart' show FakePhotoPicker, photo;
import '../support/rent_support.dart';
import '../support/support.dart';
import '../support/tenancy_support.dart';

const owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Olive Owner', emailVerified: true, roles: [UserRole.guest, UserRole.owner]);

class _Hostels extends HostHostelsNotifier {
  @override
  Future<Paged<OwnerHostel>> fetch(String? cursor) async => const Paged(items: []);
}

List<Override> over(FakeTenancyRepository repo, {AppUser user = guestUser, FakeRentRepository? rent}) => [
  sessionProvider.overrideWith(() => FakeSession(user)),
  tenancyRepositoryProvider.overrideWithValue(repo),
  rentRepositoryProvider.overrideWithValue(rent ?? FakeRentRepository()),
  hostHostelsProvider.overrideWith(_Hostels.new),
];

Tenancy stay({
  String status = 'ACTIVE',
  List<String> actions = const ['give_notice'],
  Map<String, dynamic>? notice,
  Map<String, dynamic>? settlement,
  String deposit = 'RECEIVED',
}) => Tenancy.fromJson(tenancyJson(status: status, actions: actions, deposit: deposit, notice: notice, settlement: settlement));

void main() {
  setUpAll(initLocale);

  group('the deposit receipt', () {
    testWidgets('the tenant opens it as a PDF once the deposit has been received', (t) async {
      final opened = <String>[];
      final repo = FakeTenancyRepository()..stays = [stay()];
      await pumpScreen(
        t,
        const MyStayScreen(),
        overrides: [
          ...over(repo),
          urlOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Deposit receipt (PDF)'));
      await t.pumpAndSettle();
      expect(repo.lastReceiptAsHost, false);
      expect(opened, [repo.depositReceiptUrl]);
    });

    testWidgets('there is none while the deposit is still due', (t) async {
      final repo = FakeTenancyRepository()..stays = [stay(deposit: 'DUE')];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 1600));
      await t.pumpAndSettle();
      expect(find.text('Deposit receipt (PDF)'), findsNothing);
    });
  });

  group('giving notice', () {
    testWidgets('the tenant picks a move-out day at least the notice period away, and sends it', (t) async {
      final repo = FakeTenancyRepository()..stays = [stay()];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 1600));
      await t.pumpAndSettle();
      await t.tap(find.text('Give notice'));
      await t.pumpAndSettle();
      expect(find.textContaining('30 days'), findsOneWidget); // this stay needs a month's notice
      await t.tap(find.text('Give notice').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['notice']);
      final date = DateTime.parse(repo.lastNotice!['date'] as String);
      expect(date.difference(DateTime.now()).inDays, inInclusiveRange(29, 30)); // the earliest allowed day
    });

    testWidgets('a stay on notice says when the tenant leaves, and the side that gave it can withdraw it', (t) async {
      final notice = {'givenAt': '2027-02-01T10:00:00Z', 'by': 'TENANT', 'reason': 'Course ends', 'moveOutDate': '2027-03-15'};
      final repo = FakeTenancyRepository()
        ..stays = [
          stay(status: 'NOTICE', actions: const ['withdraw_notice'], notice: notice),
        ];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 1600));
      await t.pumpAndSettle();
      expect(find.textContaining('Moving out'), findsOneWidget);
      expect(find.textContaining('You gave notice'), findsOneWidget);
      expect(find.text('Give notice'), findsNothing);
      await t.tap(find.text('Withdraw notice'));
      await t.pumpAndSettle();
      expect(repo.calls, ['withdrawNotice']);
    });

    testWidgets('notice the owner served cannot be withdrawn by the tenant', (t) async {
      final notice = {'givenAt': '2027-02-01T10:00:00Z', 'by': 'OWNER', 'reason': null, 'moveOutDate': '2027-03-15'};
      final repo = FakeTenancyRepository()..stays = [stay(status: 'NOTICE', actions: const [], notice: notice)];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 1600));
      await t.pumpAndSettle();
      expect(find.textContaining('The owner gave notice'), findsOneWidget);
      expect(find.text('Withdraw notice'), findsNothing);
    });
  });

  group('paying the deposit online', () {
    testWidgets('is offered while the deposit is due, and starts a deposit order (not an invoice payment)', (t) async {
      final rent = FakeRentRepository();
      final repo = FakeTenancyRepository()
        ..stays = [
          stay(status: 'PENDING_MOVE_IN', actions: const ['decline', 'pay_deposit'], deposit: 'DUE'),
        ];
      await pumpScreen(
        t,
        const MyStayScreen(),
        overrides: over(repo, rent: rent),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Pay deposit online'));
      await t.pumpAndSettle();
      expect(find.text('Pay the security deposit'), findsOneWidget);
      expect(rent.calls, ['startDeposit:t1']);
      expect(find.text('Pay ₹15,000'), findsOneWidget); // the stay's deposit
      await t.tap(find.text('Pay ₹15,000'));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(rent.calls, contains('checkout:DEMO_SUCCESS'));
      expect(find.text('Deposit paid'), findsWidgets);
    });

    testWidgets('is not offered once the deposit has been received', (t) async {
      final repo = FakeTenancyRepository()
        ..stays = [
          stay(status: 'PENDING_MOVE_IN', actions: const ['decline']),
        ];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 1600));
      await t.pumpAndSettle();
      expect(find.text('Pay deposit online'), findsNothing);
    });

    test('a deposit order parses even though it has no invoice', () {
      final o = RentOrder.fromJson({...orderJson(), 'invoiceId': null, 'tenancyId': 't1', 'kind': 'DEPOSIT'});
      expect(o.invoiceId, isNull);
      expect(o.kind, 'DEPOSIT');
      expect(o.tenancyId, 't1');
    });
  });

  group('the deposit settlement (tenant)', () {
    final ref = {'id': 'st1', 'status': 'PROPOSED', 'refundPaise': 1200000};

    testWidgets('shows what is deducted and what comes back, and can be accepted', (t) async {
      final repo = FakeTenancyRepository()..stays = [stay(status: 'ENDED', actions: const [], settlement: ref)];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 2000));
      await t.pumpAndSettle();
      expect(find.text('Your deposit'), findsOneWidget);
      expect(find.text('Deposit held'), findsOneWidget);
      expect(find.textContaining('Unpaid rent, invoice INV-2702-ABC234'), findsOneWidget);
      expect(find.textContaining('Broken window latch'), findsOneWidget);
      expect(find.text('Comes back to the tenant'), findsOneWidget);
      expect(find.textContaining('Respond by'), findsOneWidget);
      await t.tap(find.text('Accept'));
      await t.pumpAndSettle();
      expect(repo.calls, ['acceptSettlement']);
    });

    testWidgets('disputing needs a reason, then sends it', (t) async {
      final repo = FakeTenancyRepository()..stays = [stay(status: 'ENDED', actions: const [], settlement: ref)];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 2000));
      await t.pumpAndSettle();
      await t.tap(find.text('Dispute'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send dispute'));
      await t.pumpAndSettle();
      expect(find.textContaining('at least 5'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await t.enterText(find.byType(TextField).last, 'The latch was already broken');
      await t.tap(find.text('Send dispute'));
      await t.pumpAndSettle();
      expect(repo.lastDispute, 'The latch was already broken');
    });

    testWidgets('a settled deposit says how it came back, and offers nothing more', (t) async {
      final repo = FakeTenancyRepository()
        ..settlementData = DepositSettlement.fromJson(settlementJson(status: 'COMPLETED', actions: const [], online: true, payoutMethod: 'ONLINE'))
        ..stays = [
          stay(status: 'ENDED', actions: const [], settlement: {'id': 'st1', 'status': 'COMPLETED', 'refundPaise': 1200000}),
        ];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 2000));
      await t.pumpAndSettle();
      expect(find.textContaining('refunded to the original payment method'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('a disputed settlement shows what the tenant said', (t) async {
      final repo = FakeTenancyRepository()
        ..settlementData = DepositSettlement.fromJson(settlementJson(status: 'DISPUTED', actions: const [], disputeNote: 'Already broken'))
        ..stays = [
          stay(status: 'ENDED', actions: const [], settlement: {'id': 'st1', 'status': 'DISPUTED', 'refundPaise': 1200000}),
        ];
      await pumpScreen(t, const MyStayScreen(), overrides: over(repo), size: const Size(390, 2000));
      await t.pumpAndSettle();
      expect(find.textContaining('The tenant says: Already broken'), findsOneWidget);
    });
  });

  group('the owner on a stay', () {
    Future<FakeTenancyRepository> open(WidgetTester t, Tenancy x, {DepositSettlement? settlement, List<Override> extra = const []}) async {
      final repo = FakeTenancyRepository()..hostStays = [x];
      if (settlement != null) repo.settlementData = settlement;
      await pumpScreen(
        t,
        const HostTenantsScreen(),
        overrides: [
          ...over(repo, user: owner),
          ...extra,
        ],
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Stays'));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('can serve notice, and record a move-out', (t) async {
      final repo = await open(t, stay(actions: const ['serve_notice', 'move_out']));
      expect(find.text('Serve notice'), findsOneWidget);
      await t.tap(find.text('Serve notice'));
      await t.pumpAndSettle();
      await t.tap(find.text('Serve notice').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['serveNotice']);

      await t.tap(find.text('Record move-out'));
      await t.pumpAndSettle();
      expect(find.textContaining('This cannot be undone'), findsOneWidget);
      await t.tap(find.text('Record move-out').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['serveNotice', 'moveOut']);
      expect(DateTime.parse(repo.lastMoveOut!).day, DateTime.now().day);
    });

    testWidgets('sees who gave notice, and can withdraw only their own', (t) async {
      final notice = {'givenAt': '2027-02-01T10:00:00Z', 'by': 'OWNER', 'reason': null, 'moveOutDate': '2027-03-15'};
      final repo = await open(t, stay(status: 'NOTICE', actions: const ['withdraw_notice', 'move_out'], notice: notice));
      expect(find.textContaining('you served notice'), findsOneWidget);
      await t.tap(find.text('Withdraw notice'));
      await t.pumpAndSettle();
      expect(repo.calls, ['ownerWithdrawNotice']);
    });

    Future<FakeTenancyRepository> openDraft(WidgetTester t, {DepositSettlement? settlement, FakePhotoPicker? picker}) async {
      final draft = settlement ?? DepositSettlement.fromJson(settlementJson(status: 'DRAFT', actions: const ['edit', 'add_proof', 'propose']));
      final repo = await open(
        t,
        stay(status: 'ENDED', actions: const ['settle'], settlement: {'id': 'st1', 'status': 'DRAFT', 'refundPaise': 1200000}),
        settlement: draft,
        extra: [if (picker != null) photoPickerProvider.overrideWithValue(picker)],
      );
      await t.tap(find.text('Settle the deposit'));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('settles the deposit: saves the itemised draft, then sends it to the tenant', (t) async {
      final repo = await openDraft(t);
      expect(find.text('Deposit settlement'), findsWidgets);
      expect(find.textContaining('use the website'), findsNothing); // the app edits it now
      expect(find.textContaining('back to the tenant'), findsOneWidget);
      await t.tap(find.text('Send to the tenant'));
      await t.pumpAndSettle();
      expect(repo.calls, ['save', 'propose']); // saved first, so the tenant sees the final numbers
      expect(repo.savedLines!.map((l) => l['type']), ['UNPAID_RENT', 'DAMAGE']);
      expect(repo.savedLines!.first['invoiceId'], 'i1');
      expect(repo.savedLines!.first['amountPaise'], 250000);
    });

    testWidgets('the owner edits a deduction and adds another, and the total follows', (t) async {
      final repo = await openDraft(t);
      await t.enterText(find.widgetWithText(TextField, '500').first, '800');
      await t.pump();
      expect(find.textContaining('Deductions ₹3,300'), findsOneWidget);
      await t.tap(find.text('Add a deduction'));
      await t.pumpAndSettle();
      expect(find.text('Deduction 3'), findsOneWidget);
      await t.tap(find.text('Save draft'));
      await t.pumpAndSettle();
      expect(repo.calls, isNot(contains('save'))); // the new empty line must be filled in first
      expect(find.text('Say what each deduction is for'), findsOneWidget);
    });

    testWidgets('deductions above the deposit cannot be saved or sent', (t) async {
      final repo = await openDraft(t);
      await t.enterText(find.widgetWithText(TextField, '500').first, '20000');
      await t.pump();
      expect(find.textContaining('more than the deposit'), findsOneWidget);
      await t.tap(find.text('Save draft'));
      await t.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.textContaining('at most the deposit held'), findsOneWidget);
    });

    testWidgets('a disputed settlement shows the tenant\'s reason and can be revised and sent again', (t) async {
      final disputed = DepositSettlement.fromJson(
        settlementJson(status: 'DISPUTED', actions: const ['edit', 'add_proof', 'propose'], disputeNote: 'The latch was already broken'),
      );
      final repo = await openDraft(t, settlement: disputed);
      expect(find.textContaining('The latch was already broken'), findsOneWidget);
      await t.tap(find.text('Send to the tenant'));
      await t.pumpAndSettle();
      expect(repo.calls, ['save', 'propose']);
    });

    testWidgets('evidence photos are uploaded one by one and can be removed', (t) async {
      final picker = FakePhotoPicker()..gallery = [photo('a.png'), photo('b.png')];
      final repo = await openDraft(t, picker: picker);
      await t.tap(find.text('Add photos (optional)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose from gallery'));
      await t.pumpAndSettle();
      expect(repo.addedProofs, ['a.png', 'b.png']);
      expect(find.bySemanticsLabel('Remove evidence photo 2'), findsOneWidget);
      await t.ensureVisible(find.byIcon(Icons.close_rounded).last);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close_rounded).last);
      await t.pumpAndSettle();
      expect(repo.removedProofs, ['pf1']);
    });

    testWidgets('the owner opens the deposit receipt from the tenants list', (t) async {
      final opened = <String>[];
      final repo = await open(
        t,
        stay(status: 'ACTIVE', actions: const [], settlement: null),
        extra: [
          urlOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
      );
      await t.tap(find.text('Deposit receipt'));
      await t.pumpAndSettle();
      expect(repo.calls, contains('depositReceipt'));
      expect(repo.lastReceiptAsHost, true);
      expect(opened, [repo.depositReceiptUrl]);
    });

    testWidgets('records how a cash deposit refund was paid', (t) async {
      final agreed = DepositSettlement.fromJson(settlementJson(status: 'AGREED', actions: const ['record_payout']));
      final repo = await open(
        t,
        stay(status: 'ENDED', actions: const ['settle'], settlement: {'id': 'st1', 'status': 'AGREED', 'refundPaise': 1200000}),
        settlement: agreed,
      );
      await t.tap(find.text('Settle the deposit'));
      await t.pumpAndSettle();
      expect(find.textContaining('not paid online'), findsOneWidget);
      await t.tap(find.text('Cash'));
      await t.pump();
      await t.tap(find.text('Record refund'));
      await t.pumpAndSettle();
      expect(repo.lastPayout?.method, 'CASH');
    });

    testWidgets('a proposal waiting for the tenant can be taken back', (t) async {
      final sent = DepositSettlement.fromJson(settlementJson(actions: const ['retract']));
      final repo = await open(
        t,
        stay(status: 'ENDED', actions: const ['settle'], settlement: {'id': 'st1', 'status': 'PROPOSED', 'refundPaise': 1200000}),
        settlement: sent,
      );
      await t.tap(find.text('Settle the deposit'));
      await t.pumpAndSettle();
      await t.tap(find.text('Take it back to edit'));
      await t.pumpAndSettle();
      expect(repo.calls, ['retract']);
    });
  });
}
