import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/core/format/format.dart';
import 'package:hostel_booking_app/features/complaints/domain/complaint_models.dart';
import 'package:hostel_booking_app/features/complaints/presentation/availability_widgets.dart';
import 'package:hostel_booking_app/features/complaints/presentation/complaint_detail_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/my_complaints_screen.dart';
import 'package:hostel_booking_app/features/complaints/presentation/staff_jobs_screen.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';

import '../support/complaint_support.dart';
import '../support/support.dart';
import '../support/tenancy_support.dart';

const staffUser = AppUser(id: 'st1', email: 'ravi@example.com', fullName: 'Ravi Kumar', emailVerified: true, roles: [UserRole.guest, UserRole.staff]);

List<Override> over(FakeComplaintRepository repo, {AppUser user = guestUser, FakeTenancyRepository? stays}) => [
  sessionProvider.overrideWith(() => FakeSession(user)),
  complaintRepositoryProvider.overrideWithValue(repo),
  tenancyRepositoryProvider.overrideWithValue(
    stays ?? (FakeTenancyRepository()..stays = [Tenancy.fromJson(tenancyJson(status: 'ACTIVE', actions: const []))]),
  ),
];

void main() {
  setUpAll(initLocale);

  group('My complaints', () {
    testWidgets('lists complaints with their status', (t) async {
      final repo = FakeComplaintRepository()
        ..items = [
          ComplaintSummary.fromJson(complaintSummaryJson()),
          ComplaintSummary.fromJson(complaintSummaryJson(id: 'c2', status: 'RESOLVED', title: 'Light flickers')),
        ];
      await pumpScreen(t, const MyComplaintsScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      expect(find.text('Tap is leaking'), findsOneWidget);
      expect(find.text('Light flickers'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('New complaint'), findsOneWidget);
    });

    testWidgets('someone who has not moved in is told why they cannot file', (t) async {
      final repo = FakeComplaintRepository();
      await pumpScreen(t, const MyComplaintsScreen(), overrides: over(repo, stays: FakeTenancyRepository()));
      await t.pumpAndSettle();
      expect(find.textContaining('once you have moved in'), findsOneWidget);
      expect(find.text('New complaint'), findsNothing);
    });

    testWidgets('filing asks for a title and a description first, then sends the complaint', (t) async {
      final repo = FakeComplaintRepository();
      await pumpScreen(t, const MyComplaintsScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('New complaint'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send complaint'));
      await t.pumpAndSettle();
      expect(find.text('Give it a short title'), findsOneWidget);
      expect(find.text('Describe what is wrong'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await t.enterText(find.widgetWithText(TextField, 'Tap is leaking').first, 'Tap is leaking');
      await t.enterText(find.byType(TextField).at(1), 'The bathroom tap drips all night.');
      await t.tap(find.text('Send complaint'));
      await t.pumpAndSettle();
      expect(repo.calls, ['file']);
      expect(repo.lastFile, containsPair('category', 'PLUMBING'));
      expect(repo.lastFile, containsPair('priority', 'MEDIUM'));
      expect(repo.lastFile!['allowEntry'], false);
      final from = repo.lastFile!['from'] as DateTime;
      final to = repo.lastFile!['to'] as DateTime;
      expect(to.difference(from), const Duration(hours: 12)); // the default free time: 9am to 9pm tomorrow
      expect(from.isAfter(DateTime.now()), true);
    });
  });

  group('Free time and visits', () {
    testWidgets('the form asks when you are free, and a preset changes the times', (t) async {
      final repo = FakeComplaintRepository();
      await pumpScreen(t, const MyComplaintsScreen(), overrides: over(repo));
      await t.pumpAndSettle();
      await t.tap(find.text('New complaint'));
      await t.pumpAndSettle();
      expect(find.textContaining('When are you free to let someone in?'), findsOneWidget);
      await t.dragUntilVisible(find.text('Morning'), find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await t.tap(find.text('Morning'));
      await t.pump();
      await t.enterText(find.byType(TextField).first, 'Tap is leaking');
      await t.enterText(find.byType(TextField).at(1), 'The bathroom tap drips all night.');
      await t.dragUntilVisible(find.text('Send complaint'), find.byType(SingleChildScrollView).last, const Offset(0, 200));
      await t.tap(find.text('Send complaint'));
      await t.pumpAndSettle();
      final from = repo.lastFile!['from'] as DateTime;
      final to = repo.lastFile!['to'] as DateTime;
      expect(to.difference(from), const Duration(hours: 3)); // 9am to 12pm
    });

    testWidgets('staff and tenant both see the free time; the tenant can change it', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(complaintDetailJson(actions: const ['comment', 'close', 'set_availability']));
      await pumpScreen(t, const ComplaintDetailScreen(id: 'c1'), overrides: over(repo));
      await t.pumpAndSettle();
      expect(find.text('Your free time'), findsOneWidget);
      expect(find.textContaining('someone will be home'), findsOneWidget);
      expect(find.text('Change my free time'), findsOneWidget);
      await t.tap(find.text('Change my free time'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.calls, ['tenant:set_availability']);
      expect(repo.lastAction!['action'], 'set_availability');
      expect(repo.lastAction!['allowEntryIfAway'], false);
      expect(DateTime.parse(repo.lastAction!['availableTo'] as String).isAfter(DateTime.parse(repo.lastAction!['availableFrom'] as String)), true);
    });

    testWidgets('staff book a visit inside the free time', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(
          complaintDetailJson(status: 'ASSIGNED', viewer: 'STAFF', actions: const ['comment', 'start', 'hold', 'resolve', 'schedule']),
        );
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1', staff: true),
        overrides: over(repo, user: staffUser),
      );
      await t.pumpAndSettle();
      expect(find.text('Tenant is free'), findsOneWidget);
      expect(find.text('Not booked yet'), findsOneWidget);
      await t.tap(find.text('Book a visit'));
      await t.pumpAndSettle();
      expect(find.textContaining('Pick a time inside it'), findsOneWidget);
      await t.tap(find.text('Book visit'));
      await t.pumpAndSettle();
      expect(repo.calls, ['staff:schedule']);
      final start = DateTime.parse(repo.lastAction!['visitStart'] as String);
      final end = DateTime.parse(repo.lastAction!['visitEnd'] as String);
      expect(end.difference(start), const Duration(hours: 1));
      expect(start, DateTime.parse('2027-02-03T10:00:00Z')); // starts where the tenant's free time starts
    });

    testWidgets('a booked visit is shown, and can be changed', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(
          complaintDetailJson(
            status: 'ASSIGNED',
            viewer: 'STAFF',
            actions: const ['comment', 'schedule'],
            visit: {'start': '2027-02-03T11:00:00Z', 'end': '2027-02-03T12:00:00Z'},
          ),
        );
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1', staff: true),
        overrides: over(repo, user: staffUser),
      );
      await t.pumpAndSettle();
      expect(find.text('Visit booked'), findsOneWidget);
      expect(find.text('Change visit time'), findsOneWidget);
      expect(find.text('Book a visit'), findsNothing);
    });

    testWidgets('the job list shows the booked visit, or the free time while none is booked', (t) async {
      final repo = FakeComplaintRepository()
        ..jobList = [
          ComplaintSummary.fromJson({
            ...complaintSummaryJson(status: 'ASSIGNED'),
            'visit': {'start': '2027-02-03T11:00:00Z', 'end': '2027-02-03T12:00:00Z'},
          }),
          ComplaintSummary.fromJson(complaintSummaryJson(id: 'c2', status: 'ASSIGNED', title: 'Light flickers')),
        ];
      await pumpScreen(t, const StaffJobsScreen(), overrides: over(repo, user: staffUser));
      await t.pumpAndSettle();
      expect(find.textContaining('Visit '), findsOneWidget);
      expect(find.textContaining('Free '), findsOneWidget);
    });

    test('a free time is checked before it is sent', () {
      final tomorrow = today().add(const Duration(days: 1));
      const nine = TimeOfDay(hour: 9, minute: 0);
      expect(FreeTime(date: tomorrow, from: nine, to: const TimeOfDay(hour: 12, minute: 0)).problem, isNull);
      expect(FreeTime(date: tomorrow, from: const TimeOfDay(hour: 12, minute: 0), to: nine).problem, contains('after the start'));
      expect(FreeTime(date: tomorrow, from: nine, to: const TimeOfDay(hour: 9, minute: 30)).problem, contains('at least an hour'));
      expect(
        FreeTime(date: today().subtract(const Duration(days: 2)), from: nine, to: const TimeOfDay(hour: 12, minute: 0)).problem,
        contains('already passed'),
      );
    });

    test('a span reads as one day with two times', () {
      final a = DateTime(2027, 2, 3, 10, 0);
      final b = DateTime(2027, 2, 3, 13, 30);
      final text = fmtSpan(a, b);
      expect('Feb'.allMatches(text).length, 1);
      expect(text, contains('10:00'));
      expect(text, contains('1:30'));
    });
  });

  group('Complaint detail (tenant)', () {
    Future<FakeComplaintRepository> open(WidgetTester t, ComplaintDetail d) async {
      final repo = FakeComplaintRepository()..detailData = d;
      await pumpScreen(t, const ComplaintDetailScreen(id: 'c1'), overrides: over(repo));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the story and only the actions the server allows', (t) async {
      await open(t, ComplaintDetail.fromJson(complaintDetailJson()));
      expect(find.text('Tap is leaking'), findsOneWidget);
      expect(find.text('The bathroom tap drips all night.'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Rate the fix'), findsNothing);
      expect(find.text('Start work'), findsNothing);
      expect(find.text('Add a comment'), findsOneWidget);
    });

    testWidgets('a resolved complaint can be reopened with a reason and a new free time', (t) async {
      final repo = await open(
        t,
        ComplaintDetail.fromJson(
          complaintDetailJson(status: 'RESOLVED', actions: const ['comment', 'close', 'reopen', 'rate'], resolutionNote: 'Replaced the washer'),
        ),
      );
      expect(find.text('Replaced the washer'), findsOneWidget);
      await t.tap(find.text('It isn’t fixed'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.textContaining('at least 3'), findsOneWidget); // a reason is required
      expect(repo.calls, isEmpty);
      await t.enterText(find.byType(TextField).last, 'Still dripping');
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('When can someone come back?'), findsOneWidget); // then a free time for the second visit
      await t.tap(find.text('Reopen'));
      await t.pumpAndSettle();
      expect(repo.calls, ['tenant:reopen']);
      expect(repo.lastAction!['action'], 'reopen');
      expect(repo.lastAction!['reason'], 'Still dripping');
      expect(repo.lastAction!['availableFrom'], isNotNull);
      expect(repo.lastAction!['availableTo'], isNotNull);
    });

    testWidgets('rating needs a star, then sends it', (t) async {
      final repo = await open(t, ComplaintDetail.fromJson(complaintDetailJson(status: 'RESOLVED', actions: const ['comment', 'close', 'rate'])));
      await t.tap(find.text('Rate the fix'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send rating'));
      await t.pumpAndSettle();
      expect(find.text('Tap a star to rate'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('4 of 5 stars'));
      await t.pump();
      await t.tap(find.text('Send rating'));
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'rate', 'rating': 4});
    });

    testWidgets('posting a comment sends the trimmed text', (t) async {
      final repo = await open(t, ComplaintDetail.fromJson(complaintDetailJson()));
      await t.dragUntilVisible(find.text('Post comment'), find.byType(Scrollable).first, const Offset(0, -200));
      await t.enterText(find.byType(TextField).first, '  It is getting worse  ');
      await t.tap(find.text('Post comment'));
      await t.pumpAndSettle();
      expect(repo.lastComment, 'It is getting worse'.trim());
    });

    testWidgets('a server refusal is shown in words and nothing else changes', (t) async {
      final repo = await open(t, ComplaintDetail.fromJson(complaintDetailJson(status: 'RESOLVED', actions: const ['close'])));
      expect(find.text('Close it'), findsOneWidget);
      repo.failNext = Exception('boom');
      await t.tap(find.text('Close it'));
      await t.pumpAndSettle();
      await t.tap(find.text('Close').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });
  });

  group('Maintenance staff', () {
    testWidgets('someone who is not staff sees an explanation, not an empty list', (t) async {
      await pumpScreen(t, const StaffJobsScreen(), overrides: over(FakeComplaintRepository()));
      await t.pumpAndSettle();
      expect(find.text('This area is for maintenance staff'), findsOneWidget);
    });

    testWidgets('staff see their trade, properties and jobs', (t) async {
      final repo = FakeComplaintRepository()..jobList = [ComplaintSummary.fromJson(complaintSummaryJson(status: 'ASSIGNED', priority: 'URGENT'))];
      await pumpScreen(t, const StaffJobsScreen(), overrides: over(repo, user: staffUser));
      await t.pumpAndSettle();
      expect(find.textContaining('Plumber for Olive Owner'), findsOneWidget);
      expect(find.text('Tap is leaking'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.textContaining('Koregaon Park Students PG · bed B-1'), findsOneWidget);
    });

    testWidgets('a paused account is told it will not get new jobs', (t) async {
      final repo = FakeComplaintRepository()
        ..me = StaffMe.fromJson({
          'userId': 'st1',
          'trade': 'PLUMBER',
          'kind': 'OWN',
          'status': 'INACTIVE',
          'employer': null,
          'hostels': <Map<String, dynamic>>[],
          'openJobs': 0,
        });
      await pumpScreen(t, const StaffJobsScreen(), overrides: over(repo, user: staffUser));
      await t.pumpAndSettle();
      expect(find.textContaining('Paused'), findsOneWidget);
      expect(find.text('No jobs right now'), findsOneWidget);
    });

    testWidgets('starting, then resolving a job needs a note', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(
          complaintDetailJson(status: 'ASSIGNED', viewer: 'STAFF', actions: const ['comment', 'add_photo', 'start', 'hold', 'resolve']),
        );
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1', staff: true),
        overrides: over(repo, user: staffUser),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Start work'));
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'start'});

      await t.tap(find.text('Mark resolved'));
      await t.pumpAndSettle();
      await t.tap(find.text('Resolved'));
      await t.pumpAndSettle();
      expect(find.textContaining('at least 3'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'Replaced the washer');
      await t.tap(find.text('Resolved'));
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'resolve', 'note': 'Replaced the washer'});
      expect(repo.calls, ['staff:start', 'staff:resolve']);
    });

    testWidgets('holding a job asks why', (t) async {
      final repo = FakeComplaintRepository()
        ..detailData = ComplaintDetail.fromJson(
          complaintDetailJson(status: 'IN_PROGRESS', viewer: 'STAFF', actions: const ['comment', 'hold', 'resolve']),
        );
      await pumpScreen(
        t,
        const ComplaintDetailScreen(id: 'c1', staff: true),
        overrides: over(repo, user: staffUser),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Put on hold').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Waiting for a part');
      await t.tap(find.text('Put on hold').last);
      await t.pumpAndSettle();
      expect(repo.lastAction, {'action': 'hold', 'reason': 'Waiting for a part'});
    });
  });
}
