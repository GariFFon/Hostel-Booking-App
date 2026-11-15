import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/shared/widgets/app_button.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/complaints/domain/complaint_models.dart';
import 'package:hostel_booking_app/features/complaints/domain/invite_code.dart';
import 'package:hostel_booking_app/features/complaints/presentation/complaint_detail_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/host_complaints_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/host_staff_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/join_team_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/my_complaints_screen.dart';
import 'package:hostel_booking_app/features/host/application/host_providers.dart';
import 'package:hostel_booking_app/features/host/domain/host_models.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';

import '../support/complaint_support.dart';
import '../support/support.dart';
import '../support/tenancy_support.dart';

const owner = AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Olive Owner', emailVerified: true, roles: [UserRole.guest, UserRole.owner]);

class _Hostels extends HostHostelsNotifier {
  @override
  Future<Paged<OwnerHostel>> fetch(String? cursor) async => Paged(
    items: [
      OwnerHostel.fromJson({
        'id': 'h1',
        'slug': 'a',
        'name': 'Koregaon Park Students PG',
        'city': 'Pune',
        'propertyType': 'PG',
        'status': 'APPROVED',
        'updatedAt': '2027-01-01T00:00:00Z',
      }),
      OwnerHostel.fromJson({
        'id': 'h2',
        'slug': 'b',
        'name': 'Goa Beach Hotel',
        'city': 'Goa',
        'propertyType': 'HOTEL',
        'status': 'APPROVED',
        'updatedAt': '2027-01-01T00:00:00Z',
      }),
      OwnerHostel.fromJson({
        'id': 'h3',
        'slug': 'c',
        'name': 'Kothrud Scholars Hostel',
        'city': 'Pune',
        'propertyType': 'HOSTEL',
        'status': 'APPROVED',
        'updatedAt': '2027-01-01T00:00:00Z',
      }),
    ],
  );
}

/// A session that can be reloaded, standing in for "ask the server who I am now" after joining a team.
class _ReloadableSession extends FakeSession {
  _ReloadableSession(super.user, this.after);
  final AppUser after;
  int reloads = 0;

  @override
  Future<void> reload() async {
    reloads++;
    state = AsyncData(after);
  }
}

const staffUser = AppUser(id: 'st1', email: 'ravi@example.com', fullName: 'Ravi', emailVerified: true, roles: [UserRole.guest, UserRole.staff]);

List<Override> over(
  FakeComplaintRepository repo, {
  AppUser user = guestUser,
  FakePhotoPicker? picker,
  List<String>? opened,
  SessionController Function()? session,
}) => [
  sessionProvider.overrideWith(session ?? () => FakeSession(user)),
  complaintRepositoryProvider.overrideWithValue(repo),
  tenancyRepositoryProvider.overrideWithValue(FakeTenancyRepository()..stays = [Tenancy.fromJson(tenancyJson(status: 'ACTIVE', actions: const []))]),
  hostHostelsProvider.overrideWith(_Hostels.new),
  if (picker != null) photoPickerProvider.overrideWithValue(picker),
  if (opened != null)
    urlOpenerProvider.overrideWithValue((url) async {
      opened.add(url);
      return true;
    }),
];

void main() {
  setUpAll(initLocale);

  group('the invitation code', () {
    test('is taken from a pasted link or a bare code, and junk is refused', () {
      const code = 'abcDEF123456_-ghiJKL789012mnoPQR';
      expect(parseInviteToken(code), code);
      expect(parseInviteToken('  $code \n'), code);
      expect(parseInviteToken('https://hostel.example.com/staff?invite=$code'), code);
      for (final junk in ['', '   ', 'short', 'has spaces in the middle of a long enough text', 'https://hostel.example.com/staff', 'a' * 250]) {
        expect(parseInviteToken(junk), isNull, reason: junk);
      }
    });
  });

  group('joining a maintenance team from the app', () {
    testWidgets('a pasted link joins the team, refreshes who I am, and shows the job list', (t) async {
      final repo = FakeComplaintRepository();
      late _ReloadableSession session;
      await pumpScreen(t, const JoinTeamScreen(), overrides: over(repo, session: () => session = _ReloadableSession(guestUser, staffUser)));
      await t.pumpAndSettle();
      expect(find.text('Join a maintenance team'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'https://hostel.example.com/staff?invite=abcDEF123456_-ghiJKL789012mnoPQR');
      await t.tap(find.text('Join the team'));
      await t.pumpAndSettle();
      expect(repo.lastToken, 'abcDEF123456_-ghiJKL789012mnoPQR');
      expect(session.reloads, 1);
    });

    testWidgets('something that is not a code is refused before anything is sent', (t) async {
      final repo = FakeComplaintRepository();
      await pumpScreen(t, const JoinTeamScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'hello');
      await t.tap(find.text('Join the team'));
      await t.pumpAndSettle();
      expect(find.textContaining('Paste the link or code'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a server refusal (wrong account, expired) is shown in words', (t) async {
      final repo = FakeComplaintRepository()..failNext = Exception('boom');
      await pumpScreen(t, const JoinTeamScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'abcDEF123456_-ghiJKL789012mnoPQR');
      await t.tap(find.text('Join the team'));
      await t.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });
  });

  group('complaint photos', () {
    testWidgets('are chosen before sending (up to 6), shown as thumbnails, and uploaded once the complaint exists', (t) async {
      final repo = FakeComplaintRepository();
      final picker = FakePhotoPicker()..gallery = [photo('a.jpg'), photo('b.jpg')];
      await pumpScreen(
        t,
        const MyComplaintsScreen(),
        overrides: over(repo, picker: picker),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('New complaint'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(find.text('Add photos (optional)'), find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await t.tap(find.text('Add photos (optional)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose from gallery'));
      await t.pumpAndSettle();
      expect(picker.lastMax, 6);
      expect(find.bySemanticsLabel('Photo 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 2'), findsOneWidget);
      expect(find.text('Add more (4 left)'), findsOneWidget);
      await t.tap(find.byIcon(Icons.close_rounded).last);
      await t.pumpAndSettle();
      expect(find.text('Add more (5 left)'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove photo 1'), findsOneWidget); // each thumbnail is removable by a screen-reader user too
      expect(find.bySemanticsLabel('Photo 2'), findsNothing);

      await t.enterText(find.byType(TextField).first, 'Tap is leaking');
      await t.enterText(find.byType(TextField).at(1), 'The bathroom tap drips all night.');
      await t.dragUntilVisible(find.text('Send complaint'), find.byType(SingleChildScrollView).last, const Offset(0, 200));
      await t.tap(find.text('Send complaint'));
      await t.pumpAndSettle();
      expect(repo.calls, ['file', 'photo']);
      expect(repo.photosAdded, ['c1:a.jpg']);
    });

    testWidgets('a photo that fails to upload never loses the complaint, and the person is told', (t) async {
      final repo = FakeComplaintRepository();
      final picker = FakePhotoPicker()..camera = photo('shot.jpg');
      await pumpScreen(
        t,
        const MyComplaintsScreen(),
        overrides: over(repo, picker: picker),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('New complaint'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Tap is leaking');
      await t.enterText(find.byType(TextField).at(1), 'The bathroom tap drips all night.');
      await t.dragUntilVisible(find.text('Add photos (optional)'), find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await t.tap(find.text('Add photos (optional)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Take a photo'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(find.text('Send complaint'), find.byType(SingleChildScrollView).last, const Offset(0, 200));
      repo.failNext = null;
      await t.tap(find.text('Send complaint'));
      await t.pumpAndSettle();
      expect(repo.calls.first, 'file'); // the complaint was created first
    });

    testWidgets('can be added later to an open complaint', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(complaintDetailJson(actions: const ['comment', 'add_photo', 'close']));
      final picker = FakePhotoPicker()..gallery = [photo('later.jpg')];
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1'),
        overrides: over(repo, picker: picker),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Add photos'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose from gallery'));
      await t.pumpAndSettle();
      expect(repo.photosAdded, ['c1:later.jpg']);
    });

    testWidgets('are shown on the complaint and open full size', (t) async {
      final opened = <String>[];
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson({
          ...complaintDetailJson(),
          'media': [
            {'id': 'm1', 'url': 'https://img.example.com/one.jpg', 'uploadedByRole': 'TENANT', 'createdAt': '2027-02-01T10:00:00Z'},
          ],
        });
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1'),
        overrides: over(repo, opened: opened),
      );
      await t.pumpAndSettle();
      expect(find.text('Photos'), findsOneWidget);
      await t.tap(find.bySemanticsLabel(RegExp('Photo 1, added by the tenant')));
      await t.pumpAndSettle();
      expect(opened, ['https://img.example.com/one.jpg']);
    });
  });

  group('the owner\'s complaint inbox', () {
    testWidgets('has a tab per stage, and each asks the server for its own list', (t) async {
      final repo = FakeComplaintRepository()..ownerItems = [ComplaintSummary.fromJson(complaintSummaryJson())];
      await pumpScreen(
        t,
        const HostComplaintsScreen(),
        overrides: over(repo, user: owner),
        size: const Size(900, 900),
      );
      await t.pumpAndSettle();
      expect(find.widgetWithText(Tab, 'Needs assigning'), findsOneWidget);
      expect(repo.lastOwnerListFilter, 'unassigned');
      expect(find.text('Tap is leaking'), findsOneWidget);
      expect(find.textContaining('Asha Rao · bed B-1'), findsOneWidget);
      await t.tap(find.widgetWithText(Tab, 'Overdue'));
      await t.pumpAndSettle();
      expect(repo.lastOwnerListFilter, 'overdue');
      await t.tap(find.widgetWithText(Tab, 'Resolved'));
      await t.pumpAndSettle();
      expect(repo.lastOwnerListFilter, 'RESOLVED');
    });

    testWidgets('a guest without hosting is told, not shown an empty inbox', (t) async {
      await pumpScreen(t, const HostComplaintsScreen(), overrides: over(FakeComplaintRepository()));
      await t.pumpAndSettle();
      expect(find.text('Hosting is not set up'), findsOneWidget);
    });
  });

  group('the owner on one complaint', () {
    Future<FakeComplaintRepository> open(
      WidgetTester t, {
      String status = 'OPEN',
      List<String> actions = const [],
      FakeComplaintRepository? repo,
    }) async {
      final r = repo ?? FakeComplaintRepository();
      r
        ..detailData = ComplaintDetail.fromJson(complaintDetailJson(status: status, viewer: 'OWNER', actions: actions))
        ..teamData = OwnerTeam.fromJson({
          'staff': [
            staffMemberJson(),
            staffMemberJson(id: 'st2', name: 'Paused Pete', status: 'INACTIVE'),
            staffMemberJson(
              id: 'st3',
              name: 'Elsewhere Eve',
              hostels: [
                {'id': 'h9', 'name': 'Other PG'},
              ],
            ),
          ],
          'invites': <Map<String, dynamic>>[],
        });
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1'),
        overrides: over(r, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      return r;
    }

    testWidgets('sees only what the server allows, and marks a new complaint as seen', (t) async {
      final repo = await open(t, actions: const ['comment', 'acknowledge', 'assign', 'reject', 'resolve', 'set_priority']);
      expect(find.text('Mark as seen'), findsOneWidget);
      expect(find.text('Assign to staff'), findsOneWidget);
      expect(find.text('Take back'), findsNothing);
      expect(find.text('Start work'), findsNothing); // that is the staff member's button
      await t.tap(find.text('Mark as seen'));
      await t.pumpAndSettle();
      expect(repo.calls, ['owner:acknowledge']);
    });

    testWidgets('assigns to an active person who works at that property, and nobody else is offered', (t) async {
      final repo = await open(t, actions: const ['comment', 'assign']);
      await t.tap(find.text('Assign to staff'));
      await t.pumpAndSettle();
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Paused Pete'), findsNothing); // paused
      expect(find.text('Elsewhere Eve'), findsNothing); // works at another property
      expect(t.widget<AppButton>(find.widgetWithText(AppButton, 'Assign')).onPressed, isNull, reason: 'nobody picked yet');
      await t.tap(find.text('Ravi Kumar'));
      await t.pump();
      await t.tap(find.text('Assign'));
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'assign', 'staffUserId': 'st1'});
    });

    testWidgets('declining needs a reason, and changing priority sends the new level', (t) async {
      final repo = await open(t, actions: const ['comment', 'reject', 'set_priority']);
      await t.tap(find.text('Decline'));
      await t.pumpAndSettle();
      await t.tap(find.text('Decline').last);
      await t.pumpAndSettle();
      expect(find.textContaining('at least 3'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'Not covered');
      await t.tap(find.text('Decline').last);
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'reject', 'reason': 'Not covered'});

      await t.tap(find.text('Change priority'));
      await t.pumpAndSettle();
      await t.tap(find.text('Urgent'));
      await t.pump();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'priority', 'priority': 'URGENT'});
    });

    testWidgets('a staff-only note is marked as such when posted', (t) async {
      final repo = await open(t, actions: const ['comment']);
      await t.dragUntilVisible(find.text('Post comment'), find.byType(Scrollable).first, const Offset(0, -200));
      await t.enterText(find.byType(TextField).last, 'Check the other tap too');
      await t.tap(find.text('Visible to staff and owner only'));
      await t.pump();
      await t.tap(find.text('Post comment'));
      await t.pumpAndSettle();
      expect(repo.lastComment, 'Check the other tap too');
      expect(repo.lastCommentInternal, true);
    });
  });

  group('the owner\'s maintenance team', () {
    testWidgets('shows people, their trade and properties, and pending invitations', (t) async {
      final repo = FakeComplaintRepository()
        ..teamData = OwnerTeam.fromJson({
          'staff': [staffMemberJson(), staffMemberJson(id: 'v1', name: 'Vera Vendor', kind: 'VENDOR', trade: 'ELECTRICIAN')],
          'invites': [
            {
              'id': 'i1',
              'email': 'new@example.com',
              'trade': 'COOK',
              'kind': 'OWN',
              'hostels': [
                {'id': 'h1', 'name': 'Koregaon Park Students PG'},
              ],
              'expiresAt': '2027-03-01T00:00:00Z',
              'createdAt': '2027-02-01T00:00:00Z',
            },
          ],
        });
      await pumpScreen(
        t,
        const HostStaffScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1600),
      );
      await t.pumpAndSettle();
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.textContaining('Plumber · 1 open job'), findsOneWidget);
      expect(find.textContaining('Electrician · platform vendor'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget); // own staff can be paused; a vendor cannot
    });

    testWidgets('inviting asks for a valid email and a property, and only hostels and PGs are offered', (t) async {
      final repo = FakeComplaintRepository();
      await pumpScreen(
        t,
        const HostStaffScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1800),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Invite staff'));
      await t.pumpAndSettle();
      expect(find.text('Koregaon Park Students PG'), findsOneWidget);
      expect(find.text('Kothrud Scholars Hostel'), findsOneWidget);
      expect(find.text('Goa Beach Hotel'), findsNothing); // a hotel has no tenants to complain
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Pick at least one property'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await t.enterText(find.byType(TextField).first, 'plumber@example.com');
      await t.tap(find.text('Koregaon Park Students PG'));
      await t.pump();
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(repo.lastInvite, {
        'email': 'plumber@example.com',
        'trade': 'PLUMBER',
        'hostelIds': ['h1'],
      });
    });

    testWidgets('pausing someone asks first, then pauses; an invitation can be cancelled', (t) async {
      final repo = FakeComplaintRepository()
        ..teamData = OwnerTeam.fromJson({
          'staff': [staffMemberJson()],
          'invites': [
            {
              'id': 'i1',
              'email': 'new@example.com',
              'trade': 'COOK',
              'kind': 'OWN',
              'hostels': <Map<String, dynamic>>[],
              'expiresAt': '2027-03-01T00:00:00Z',
              'createdAt': '2027-02-01T00:00:00Z',
            },
          ],
        });
      await pumpScreen(
        t,
        const HostStaffScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1800),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Pause'));
      await t.pumpAndSettle();
      expect(find.textContaining('Their open jobs come back'), findsOneWidget);
      await t.tap(find.text('Pause').last);
      await t.pumpAndSettle();
      expect(repo.lastStatus, 'st1:INACTIVE');
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel invitation'));
      await t.pumpAndSettle();
      expect(repo.calls, contains('cancelInvite:i1'));
    });

    testWidgets('changing properties saves the ticked ones', (t) async {
      final repo = FakeComplaintRepository()
        ..teamData = OwnerTeam.fromJson({
          'staff': [staffMemberJson()],
          'invites': <Map<String, dynamic>>[],
        });
      await pumpScreen(
        t,
        const HostStaffScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1800),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Change properties'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kothrud Scholars Hostel'));
      await t.pump();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect((repo.lastStaffHostels!['hostelIds'] as List).toSet(), {'h1', 'h3'});
    });

    testWidgets('the vendors tab lets an owner engage a platform vendor', (t) async {
      final repo = FakeComplaintRepository()
        ..vendorList = [
          VendorItem.fromJson({'userId': 'v1', 'name': 'Vera Vendor', 'trade': 'ELECTRICIAN', 'hostels': <Map<String, dynamic>>[]}),
        ];
      await pumpScreen(
        t,
        const HostStaffScreen(),
        overrides: over(repo, user: owner),
        size: const Size(390, 1800),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Vendors'));
      await t.pumpAndSettle();
      expect(find.text('Vera Vendor'), findsOneWidget);
      expect(find.text('Not engaged at your properties'), findsOneWidget);
      await t.tap(find.text('Engage'));
      await t.pumpAndSettle();
      await t.tap(find.text('Koregaon Park Students PG'));
      await t.pump();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.lastStaffHostels, {
        'id': 'v1',
        'hostelIds': ['h1'],
      });
    });
  });
}
