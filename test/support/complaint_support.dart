import 'dart:typed_data';

import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/util/photo_picker.dart';
import 'package:hostel_booking_app/features/complaints/data/complaint_repository.dart';
import 'package:hostel_booking_app/features/complaints/domain/complaint_models.dart';

const _hostel = {'id': 'h1', 'name': 'Koregaon Park Students PG', 'city': 'Pune'};

Map<String, dynamic> complaintSummaryJson({
  String id = 'c1',
  String status = 'OPEN',
  String priority = 'MEDIUM',
  bool breached = false,
  String title = 'Tap is leaking',
}) => {
  'id': id,
  'code': 'CMP-ABC234',
  'status': status,
  'category': 'PLUMBING',
  'priority': priority,
  'title': title,
  'location': 'Bed B-1',
  'hostel': _hostel,
  'unitLabel': 'B-1',
  'raisedBy': {'id': 's1', 'name': 'Asha Rao', 'phone': '+919800000001', 'email': 'asha@example.com'},
  'assignedStaff': null,
  'slaDueAt': '2027-02-02T10:00:00Z',
  'slaBreached': breached,
  'availability': {'from': '2027-02-03T10:00:00Z', 'to': '2027-02-03T14:00:00Z', 'allowEntryIfAway': false},
  'visit': null,
  'mediaCount': 0,
  'commentCount': 0,
  'rating': null,
  'reopenCount': 0,
  'createdAt': '2027-02-01T10:00:00Z',
  'updatedAt': '2027-02-01T10:00:00Z',
};

Map<String, dynamic> complaintDetailJson({
  String status = 'OPEN',
  String viewer = 'TENANT',
  List<String> actions = const ['comment', 'add_photo', 'close'],
  List<Map<String, dynamic>> comments = const [],
  String? resolutionNote,
  int? rating,
  Map<String, dynamic>? visit,
}) => {
  ...complaintSummaryJson(status: status),
  'visit': visit,
  'description': 'The bathroom tap drips all night.',
  'acknowledgedAt': null,
  'resolvedAt': null,
  'resolutionNote': resolutionNote,
  'closedAt': null,
  'feedback': null,
  'rating': rating,
  'media': <Map<String, dynamic>>[],
  'comments': comments,
  'history': [
    {'id': 'hh1', 'fromStatus': null, 'toStatus': 'OPEN', 'actorRole': 'TENANT', 'note': null, 'createdAt': '2027-02-01T10:00:00Z'},
  ],
  'viewer': viewer,
  'version': 1,
  'actions': actions,
};

Map<String, dynamic> staffMemberJson({
  String id = 'st1',
  String name = 'Ravi Kumar',
  String trade = 'PLUMBER',
  String kind = 'OWN',
  String status = 'ACTIVE',
  List<Map<String, dynamic>>? hostels,
  int openJobs = 1,
}) => {
  'userId': id,
  'name': name,
  'email': '$id@example.com',
  'phone': null,
  'trade': trade,
  'kind': kind,
  'status': status,
  'hostels':
      hostels ??
      [
        {'id': 'h1', 'name': 'Koregaon Park Students PG'},
      ],
  'openJobs': openJobs,
  'createdAt': '2027-01-01T00:00:00Z',
};

/// A photo picker that hands back what the test gives it.
class FakePhotoPicker implements PhotoPicker {
  List<PickedPhoto> gallery = const [];
  PickedPhoto? camera;
  int galleryCalls = 0;
  int? lastMax;

  @override
  Future<List<PickedPhoto>> fromGallery({required int max}) async {
    galleryCalls++;
    lastMax = max;
    return gallery.take(max).toList();
  }

  @override
  Future<PickedPhoto?> fromCamera() async => camera;
}

/// A real 1x1 PNG, so the thumbnail decodes like a genuine photo would.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

PickedPhoto photo(String name) => PickedPhoto(name: name, bytes: _png);

/// A scripted repository: set what a test cares about, and read back what the UI sent.
class FakeComplaintRepository implements ComplaintRepository {
  List<ComplaintSummary> items = const [];
  List<ComplaintSummary> jobList = const [];
  ComplaintDetail detailData = ComplaintDetail.fromJson(complaintDetailJson());
  StaffMe me = StaffMe.fromJson({
    'userId': 'st1',
    'trade': 'PLUMBER',
    'kind': 'OWN',
    'status': 'ACTIVE',
    'employer': 'Olive Owner',
    'hostels': [_hostel],
    'openJobs': 1,
  });

  OwnerTeam teamData = OwnerTeam.fromJson({'staff': <Map<String, dynamic>>[], 'invites': <Map<String, dynamic>>[]});
  List<VendorItem> vendorList = const [];
  List<ComplaintSummary> ownerItems = const [];
  final photosAdded = <String>[];
  Map<String, Object?>? lastInvite;
  Map<String, Object?>? lastStaffHostels;
  String? lastStatus;
  String? lastToken;
  String? lastOwnerListFilter;
  final calls = <String>[];
  Map<String, Object?>? lastFile;
  Map<String, Object?>? lastAction;
  String? lastComment;
  bool? lastCommentInternal;
  Object? failNext;

  Paged<T> _page<T>(List<T> x) => Paged<T>(items: x, nextCursor: null);

  void _maybeFail() {
    final f = failNext;
    failNext = null;
    if (f != null) throw f;
  }

  @override
  Future<Paged<ComplaintSummary>> mine({String? cursor}) async => _page(items);

  @override
  Future<ComplaintDetail> file({
    required String category,
    required String priority,
    required String title,
    required String description,
    String? location,
    required DateTime availableFrom,
    required DateTime availableTo,
    bool allowEntryIfAway = false,
  }) async {
    _maybeFail();
    calls.add('file');
    lastFile = {
      'category': category,
      'priority': priority,
      'title': title,
      'description': description,
      'location': location,
      'from': availableFrom,
      'to': availableTo,
      'allowEntry': allowEntryIfAway,
    };
    return ComplaintDetail.fromJson(complaintDetailJson());
  }

  @override
  Future<ComplaintDetail> tenantAction(String id, Map<String, Object?> body) async {
    _maybeFail();
    calls.add('tenant:${body['action']}');
    lastAction = body;
    return detailData;
  }

  @override
  Future<ComplaintDetail> detail(String id) async => detailData;

  @override
  Future<void> comment(String id, String body, {bool internal = false}) async {
    calls.add('comment');
    lastComment = body;
    lastCommentInternal = internal;
  }

  @override
  Future<StaffMe> staffMe() async => me;

  @override
  Future<Paged<ComplaintSummary>> jobs({String? cursor, bool openOnly = true}) async => _page(jobList);

  @override
  Future<ComplaintDetail> staffAction(String id, Map<String, Object?> body) async {
    _maybeFail();
    calls.add('staff:${body['action']}');
    lastAction = body;
    return detailData;
  }

  @override
  Future<StaffMe> acceptInvite(String token) async {
    _maybeFail();
    calls.add('accept');
    lastToken = token;
    return me;
  }

  @override
  Future<void> addPhoto(String complaintId, PickedPhoto photo) async {
    _maybeFail();
    calls.add('photo');
    photosAdded.add('$complaintId:${photo.name}');
  }

  @override
  Future<Paged<ComplaintSummary>> ownerList({String? cursor, bool unassigned = false, bool overdue = false, String? status}) async {
    lastOwnerListFilter = unassigned
        ? 'unassigned'
        : overdue
        ? 'overdue'
        : status ?? 'all';
    return _page(ownerItems);
  }

  @override
  Future<ComplaintDetail> ownerAction(String id, Map<String, Object?> body) async {
    _maybeFail();
    calls.add('owner:${body['action']}');
    lastAction = body;
    return detailData;
  }

  @override
  Future<OwnerTeam> team() async => teamData;

  @override
  Future<List<VendorItem>> vendors() async => vendorList;

  @override
  Future<void> invite({required String email, required String trade, required List<String> hostelIds}) async {
    _maybeFail();
    calls.add('invite');
    lastInvite = {'email': email.trim(), 'trade': trade, 'hostelIds': hostelIds};
  }

  @override
  Future<void> cancelInvite(String id) async => calls.add('cancelInvite:$id');

  @override
  Future<void> setStaffHostels(String staffUserId, List<String> hostelIds) async {
    calls.add('hostels');
    lastStaffHostels = {'id': staffUserId, 'hostelIds': hostelIds};
  }

  @override
  Future<void> setStaffStatus(String staffUserId, String status) async {
    calls.add('status');
    lastStatus = '$staffUserId:$status';
  }
}
