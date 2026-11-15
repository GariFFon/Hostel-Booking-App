import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/router/routes.dart';
import 'package:hostel_booking_app/features/notifications/domain/notification_models.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';

import '../support/tenancy_support.dart';

void main() {
  test('a tenancy parses, including what the viewer may do', () {
    final t = Tenancy.fromJson(tenancyJson(status: 'PENDING_MOVE_IN', actions: const ['decline'], warning: 'High deposit'));
    expect(t.status, TenancyStatus.pendingMoveIn);
    expect(t.status.isLive, isTrue);
    expect(t.rentPaise, 750000);
    expect(t.unit.label, 'B-1');
    expect(t.deposit.isDue, isTrue);
    expect(t.can('decline'), isTrue);
    expect(t.can('accept'), isFalse);
    expect(t.start, DateTime(2027, 2, 1));
    expect(t.tenantLabel, 'Asha Rao');
  });

  test('an unknown status falls back instead of crashing', () {
    expect(Tenancy.fromJson(tenancyJson(status: 'FROZEN')).status, TenancyStatus.unknown);
    expect(TenancyApplication.fromJson(applicationJson(status: 'LOST')).status, ApplicationStatus.unknown);
    expect(TenancyStatus.cancelled.isLive, isFalse);
    expect(TenancyStatus.invited.isLive, isTrue);
  });

  test('an application and the terms parse', () {
    final a = TenancyApplication.fromJson(applicationJson(actions: const ['approve', 'reject']));
    expect(a.status, ApplicationStatus.requested);
    expect(a.applicant.display, 'Asha Rao');
    expect(a.emergencyContact.phone, '+919876543210');
    expect(a.can('approve'), isTrue);
    final terms = TenancyTerms.fromJson(termsJson(free: 3));
    expect(terms.freeUnits, 3);
    expect(terms.rooms.single.rentPaise, 750000);
  });

  test('ordinals read naturally', () {
    expect(
      [
        for (final n in [1, 2, 3, 4, 11, 12, 13, 21, 22, 28]) ordinal(n),
      ],
      ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '28th'],
    );
  });

  test('tenancy notifications know which side they are for', () {
    final owner = NotificationItem.fromJson({
      'id': 'n',
      'type': 'TENANCY_APPROVED',
      'title': 't',
      'body': '',
      'read': false,
      'createdAt': '2027-01-01T00:00:00Z',
      'data': {'audience': 'OWNER'},
    });
    final tenant = NotificationItem.fromJson({
      'id': 'n',
      'type': 'TENANCY_STARTED',
      'title': 't',
      'body': '',
      'read': false,
      'createdAt': '2027-01-01T00:00:00Z',
      'data': {'audience': 'TENANT'},
    });
    expect(owner.type, NotificationType.tenancyApproved);
    expect(owner.forOwner, isTrue);
    expect(tenant.forOwner, isFalse);
    expect(NotificationType.rentOverdue.isTenancy, isTrue);
    expect(NotificationType.bookingConfirmed.isTenancy, isFalse);
  });

  test('the stay and tenant screens need a signed-in user', () {
    expect(Routes.needsSignIn(Routes.stay), isTrue);
    expect(Routes.needsSignIn(Routes.hostTenants), isTrue);
  });
}
