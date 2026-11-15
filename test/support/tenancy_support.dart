import 'package:hostel_booking_app/core/util/photo_picker.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/features/tenancy/data/tenancy_repository.dart';
import 'package:hostel_booking_app/features/tenancy/domain/tenancy_models.dart';

Map<String, dynamic> _person(String id, String name) => {'id': id, 'name': name, 'email': '$id@example.com', 'phone': '+919800000001'};
const _hostel = {'id': 'h1', 'slug': 'koregaon-pg', 'name': 'Koregaon Park Students PG', 'city': 'Pune', 'addressLine': '1 Main Rd'};
const _room = {'id': 'r1', 'name': 'Triple sharing', 'kind': 'DORM'};

Map<String, dynamic> tenancyJson({
  String status = 'PENDING_MOVE_IN',
  List<String> actions = const ['decline'],
  String deposit = 'DUE',
  String? warning,
  Map<String, dynamic>? notice,
  Map<String, dynamic>? settlement,
}) => {
  'id': 't1',
  'code': 'TN-ABC234',
  'status': status,
  'hostel': _hostel,
  'roomType': _room,
  'unit': {'id': 'u1', 'label': 'B-1', 'floor': 1},
  'tenant': _person('s1', 'Asha Rao'),
  'inviteEmail': null,
  'startDate': '2027-02-01',
  'endDate': null,
  'rentPaise': 750000,
  'depositPaise': 1500000,
  'dueDay': 1,
  'graceDays': 5,
  'noticeDays': 30,
  'deposit': {'status': deposit, 'receivedAt': null, 'method': null, 'reference': null},
  'depositWarning': warning,
  'emergencyContact': {'name': 'Mom', 'phone': '+919876543210'},
  'notice': notice,
  'movedOutAt': null,
  'settlement': settlement,
  'version': 1,
  'actions': actions,
};

Map<String, dynamic> applicationJson({String status = 'REQUESTED', List<String> actions = const ['withdraw'], String? note}) => {
  'id': 'a1',
  'status': status,
  'hostel': _hostel,
  'roomType': _room,
  'applicant': _person('s1', 'Asha Rao'),
  'moveInDate': '2027-02-01',
  'tenureMonths': 11,
  'occupation': 'MBA student',
  'message': 'Hello!',
  'emergencyContact': {'name': 'Mom', 'phone': '+919876543210'},
  'decisionNote': note,
  'actions': actions,
};

Map<String, dynamic> termsJson({int free = 2}) => {
  'depositMonths': 2,
  'noticeDays': 30,
  'rentDueDay': 1,
  'rentGraceDays': 5,
  'rooms': [
    {'roomTypeId': 'r1', 'name': 'Triple sharing', 'kind': 'DORM', 'gender': 'MIXED', 'rentPaise': 750000, 'freeUnits': free},
  ],
};

/// A scripted repository: set the lists and the callbacks a test cares about, and read back what the UI sent.
class FakeTenancyRepository implements TenancyRepository {
  List<Tenancy> stays = const [];
  List<TenancyApplication> applications = const [];
  List<TenancyApplication> hostRequests = const [];
  List<Tenancy> hostStays = const [];
  TenancyTerms termsData = TenancyTerms.fromJson(termsJson());

  final calls = <String>[];
  Map<String, Object?>? lastApply;
  String? lastReason;
  int? lastApproveRent;
  String? lastApproveUnit;
  List<FreeUnit> free = const [FreeUnit(id: 'u1', label: 'B-1', floor: 1), FreeUnit(id: 'u2', label: 'B-2', floor: 1)];
  List<OwnerRoom> ownerRooms = const [OwnerRoom(id: 'r1', name: 'Triple sharing', basePricePaise: 750000)];
  Map<String, Object?>? lastCreate;

  Paged<T> _page<T>(List<T> items) => Paged<T>(items: items, nextCursor: null);

  @override
  Future<TenancyTerms> terms(String idOrSlug) async => termsData;

  @override
  Future<TenancyApplication> apply(
    String hostelId, {
    required String roomTypeId,
    required String moveInDate,
    int? tenureMonths,
    String? gender,
    String? occupation,
    String? message,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) async {
    calls.add('apply');
    lastApply = {'roomTypeId': roomTypeId, 'moveInDate': moveInDate, 'gender': gender, 'name': emergencyContactName, 'phone': emergencyContactPhone};
    return TenancyApplication.fromJson(applicationJson());
  }

  @override
  Future<Paged<TenancyApplication>> myApplications({String? cursor}) async => _page(applications);

  @override
  Future<TenancyApplication> withdraw(String id) async {
    calls.add('withdraw');
    return applications.first;
  }

  @override
  Future<Paged<Tenancy>> myTenancies({String? cursor}) async => _page(stays);

  @override
  Future<Tenancy> accept(String id) async {
    calls.add('accept');
    return stays.first;
  }

  @override
  Future<Tenancy> decline(String id) async {
    calls.add('decline');
    return stays.first;
  }

  @override
  Future<Paged<TenancyApplication>> hostApplications({String? cursor}) async => _page(hostRequests);

  @override
  Future<TenancyApplication> approve(String id, {String? unitId, int? rentPaise, int? depositPaise, String? startDate}) async {
    calls.add('approve');
    lastApproveRent = rentPaise;
    lastApproveUnit = unitId;
    return hostRequests.first;
  }

  @override
  Future<TenancyApplication> reject(String id, String reason) async {
    calls.add('reject');
    lastReason = reason;
    return hostRequests.first;
  }

  @override
  Future<Paged<Tenancy>> hostTenancies({String? status, String? cursor}) async => _page(hostStays);

  @override
  Future<Tenancy> recordDeposit(String id, {required String method, String? reference}) async {
    calls.add('deposit:$method');
    return hostStays.first;
  }

  @override
  Future<Tenancy> activate(String id) async {
    calls.add('activate');
    return hostStays.first;
  }

  @override
  Future<Tenancy> cancel(String id, String reason) async {
    calls.add('cancel');
    lastReason = reason;
    return hostStays.first;
  }

  @override
  Future<List<FreeUnit>> freeUnits(String roomTypeId) async => free;

  @override
  Future<List<OwnerRoom>> rooms(String hostelId) async => ownerRooms;

  @override
  Future<Tenancy> createTenancy({
    required String roomTypeId,
    String? unitId,
    required String tenantEmail,
    required String startDate,
    int? rentPaise,
    int? depositPaise,
    String? depositMethod,
  }) async {
    calls.add('create');
    lastCreate = {
      'roomTypeId': roomTypeId,
      'unitId': unitId,
      'email': tenantEmail,
      'startDate': startDate,
      'rent': rentPaise,
      'deposit': depositPaise,
      'method': depositMethod,
    };
    return Tenancy.fromJson(tenancyJson(status: 'INVITED', actions: const []));
  }

  // ── phase 14: notice, move-out, deposit settlement ──
  DepositSettlement settlementData = DepositSettlement.fromJson(settlementJson());
  Map<String, Object?>? lastNotice;
  String? lastDispute;
  String? lastMoveOut;
  ({String method, String? reference})? lastPayout;

  @override
  Future<Tenancy> giveNotice(String id, {required String moveOutDate, String? reason}) async {
    calls.add('notice');
    lastNotice = {'date': moveOutDate, 'reason': reason};
    return stays.first;
  }

  @override
  Future<Tenancy> withdrawNotice(String id) async {
    calls.add('withdrawNotice');
    return stays.first;
  }

  @override
  Future<DepositSettlement> mySettlement(String tenancyId) async => settlementData;

  @override
  Future<DepositSettlement> acceptSettlement(String tenancyId) async {
    calls.add('acceptSettlement');
    return settlementData;
  }

  @override
  Future<DepositSettlement> disputeSettlement(String tenancyId, String note) async {
    calls.add('disputeSettlement');
    lastDispute = note;
    return settlementData;
  }

  @override
  Future<Tenancy> serveNotice(String id, {required String moveOutDate, String? reason}) async {
    calls.add('serveNotice');
    lastNotice = {'date': moveOutDate, 'reason': reason};
    return hostStays.first;
  }

  @override
  Future<Tenancy> ownerWithdrawNotice(String id) async {
    calls.add('ownerWithdrawNotice');
    return hostStays.first;
  }

  @override
  Future<Tenancy> moveOut(String id, {String? movedOutOn, String? note}) async {
    calls.add('moveOut');
    lastMoveOut = movedOutOn;
    return hostStays.first;
  }

  @override
  Future<DepositSettlement> hostSettlement(String tenancyId) async => settlementData;

  @override
  Future<DepositSettlement> proposeSettlement(String tenancyId) async {
    calls.add('propose');
    return settlementData;
  }

  @override
  Future<DepositSettlement> retractSettlement(String tenancyId) async {
    calls.add('retract');
    return settlementData;
  }

  List<Map<String, Object?>>? savedLines;
  String? savedNote;
  final addedProofs = <String>[];
  final removedProofs = <String>[];
  bool? lastReceiptAsHost;
  String depositReceiptUrl = 'https://api.example.com/api/v1/receipts/dep.sig';

  @override
  Future<String> depositReceiptLink(String tenancyId, {bool host = false}) async {
    calls.add('depositReceipt');
    lastReceiptAsHost = host;
    return depositReceiptUrl;
  }

  @override
  Future<DepositSettlement> saveSettlement(String tenancyId, {required List<Map<String, Object?>> deductions, String? note}) async {
    calls.add('save');
    savedLines = deductions;
    savedNote = note;
    return settlementData;
  }

  @override
  Future<DepositSettlement> addSettlementProof(String tenancyId, PickedPhoto photo) async {
    calls.add('addProof');
    addedProofs.add(photo.name);
    settlementData = DepositSettlement.fromJson({
      ...settlementJson(status: 'DRAFT', actions: const ['edit', 'add_proof', 'propose']),
      'proofs': [
        for (var i = 0; i < addedProofs.length; i++) {'id': 'pf$i', 'url': 'https://img.example.com/p$i.png'},
      ],
    });
    return settlementData;
  }

  @override
  Future<DepositSettlement> removeSettlementProof(String tenancyId, String proofId) async {
    calls.add('removeProof');
    removedProofs.add(proofId);
    settlementData = DepositSettlement.fromJson({
      ...settlementJson(status: 'DRAFT', actions: const ['edit', 'add_proof', 'propose']),
      'proofs': <Map<String, dynamic>>[],
    });
    return settlementData;
  }

  @override
  Future<DepositSettlement> recordPayout(String tenancyId, {required String method, String? reference}) async {
    calls.add('payout');
    lastPayout = (method: method, reference: reference);
    return settlementData;
  }
}

Map<String, dynamic> settlementJson({
  String status = 'PROPOSED',
  List<String> actions = const ['accept', 'dispute'],
  bool online = false,
  String? disputeNote,
  String? payoutMethod,
}) => {
  'id': 'st1',
  'tenancyId': 't1',
  'status': status,
  'tenant': {'id': 's1', 'name': 'Asha Rao'},
  'hostel': {'id': 'h1', 'name': 'Koregaon Park Students PG'},
  'depositPaise': 1500000,
  'deductionsPaise': 300000,
  'refundPaise': 1200000,
  'note': 'Keys returned on time',
  'disputeNote': disputeNote,
  'proposedAt': '2027-03-01T10:00:00Z',
  'respondBy': '2027-03-08T10:00:00Z',
  'respondedAt': null,
  'agreedAt': null,
  'autoAgreed': false,
  'completedAt': null,
  'payout': {'online': online, 'method': payoutMethod, 'reference': null},
  'deductions': [
    {'id': 'd1', 'type': 'UNPAID_RENT', 'description': 'Unpaid rent, invoice INV-2702-ABC234', 'amountPaise': 250000, 'invoiceId': 'i1'},
    {'id': 'd2', 'type': 'DAMAGE', 'description': 'Broken window latch', 'amountPaise': 50000, 'invoiceId': null},
  ],
  'proofs': <Map<String, dynamic>>[],
  'openInvoices': <Map<String, dynamic>>[],
  'version': 1,
  'actions': actions,
};
