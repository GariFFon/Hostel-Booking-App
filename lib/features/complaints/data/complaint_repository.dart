import 'package:dio/dio.dart' show MultipartFile;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/util/photo_picker.dart';
import '../../../core/network/envelope.dart';
import '../domain/complaint_models.dart';

/// Complaints, from the tenant's side and from a maintenance person's side. (Owners manage them on the website.)
class ComplaintRepository {
  ComplaintRepository(this._api);

  final ApiClient _api;

  // ── tenant ──
  Future<Paged<ComplaintSummary>> mine({String? cursor}) =>
      _api.getPage('/me/complaints', ComplaintSummary.fromJson, query: {'cursor': cursor, 'limit': 20});

  Future<ComplaintDetail> file({
    required String category,
    required String priority,
    required String title,
    required String description,
    String? location,
    required DateTime availableFrom,
    required DateTime availableTo,
    bool allowEntryIfAway = false,
  }) => _api.postOne(
    '/me/complaints',
    ComplaintDetail.fromJson,
    body: {
      'category': category,
      'priority': priority,
      'title': title.trim(),
      'description': description.trim(),
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
      'availableFrom': availableFrom.toUtc().toIso8601String(),
      'availableTo': availableTo.toUtc().toIso8601String(),
      'allowEntryIfAway': allowEntryIfAway,
    },
  );

  Future<ComplaintDetail> tenantAction(String id, Map<String, Object?> body) =>
      _api.postOne('/me/complaints/$id/actions', ComplaintDetail.fromJson, body: body);

  /// Uploads one photo for a complaint: the server signs the exact upload, the phone sends the file straight to the image host, and the
  /// server then re-checks it before attaching. Throws a readable [ApiException] when the file is too big or the wrong type.
  Future<void> addPhoto(String complaintId, PickedPhoto photo) async {
    final sig = asMap((await _api.post('/uploads/signature', body: {'purpose': 'COMPLAINT_IMAGE', 'complaintId': complaintId})).data);
    final maxBytes = (sig['maxBytes'] as num).toInt();
    final formats = (sig['allowedFormats'] as List).cast<String>();
    if (photo.bytes.length > maxBytes) throw ApiException.local('That photo is too large. The limit is ${maxBytes ~/ 1048576} MB.');
    if (!formats.contains(photo.extension)) {
      throw ApiException.local('Unsupported photo type. Use ${formats.map((f) => f.toUpperCase()).join(', ')}.');
    }
    await _api.uploadForm(
      sig['uploadUrl'] as String,
      (sig['fields'] as Map).map((k, v) => MapEntry('$k', '$v')),
      MultipartFile.fromBytes(photo.bytes, filename: photo.name),
    );
    await _api.post('/complaints/$complaintId/media', body: {'publicId': sig['publicId']});
  }

  // ── owner ──
  Future<Paged<ComplaintSummary>> ownerList({String? cursor, bool unassigned = false, bool overdue = false, String? status}) => _api.getPage(
    '/owner/complaints',
    ComplaintSummary.fromJson,
    query: {'cursor': cursor, 'limit': 20, 'unassigned': unassigned ? 'true' : null, 'overdue': overdue ? 'true' : null, 'status': status},
  );

  Future<ComplaintDetail> ownerAction(String id, Map<String, Object?> body) =>
      _api.postOne('/owner/complaints/$id/actions', ComplaintDetail.fromJson, body: body);

  Future<OwnerTeam> team() => _api.getOne('/owner/staff', OwnerTeam.fromJson);

  Future<List<VendorItem>> vendors() => _api.getList('/owner/staff/vendors', VendorItem.fromJson);

  Future<void> invite({required String email, required String trade, required List<String> hostelIds}) async {
    await _api.post('/owner/staff/invites', body: {'email': email.trim(), 'trade': trade, 'hostelIds': hostelIds});
  }

  Future<void> cancelInvite(String id) async {
    await _api.delete('/owner/staff/invites/$id');
  }

  Future<void> setStaffHostels(String staffUserId, List<String> hostelIds) async {
    await _api.put('/owner/staff/$staffUserId/hostels', body: {'hostelIds': hostelIds});
  }

  Future<void> setStaffStatus(String staffUserId, String status) async {
    await _api.post('/owner/staff/$staffUserId/status', body: {'status': status});
  }

  // ── shared ──
  Future<ComplaintDetail> detail(String id) => _api.getOne('/complaints/$id', ComplaintDetail.fromJson);

  Future<void> comment(String id, String body, {bool internal = false}) async {
    await _api.post('/complaints/$id/comments', body: {'body': body.trim(), 'internal': internal});
  }

  // ── staff ──
  /// Joins a maintenance team with the code from the invitation email. The old token is revoked by the server, so the caller reloads the user.
  Future<StaffMe> acceptInvite(String token) => _api.postOne('/staff-invites/accept', StaffMe.fromJson, body: {'token': token});

  Future<StaffMe> staffMe() => _api.getOne('/staff/me', StaffMe.fromJson);

  Future<Paged<ComplaintSummary>> jobs({String? cursor, bool openOnly = true}) =>
      _api.getPage('/staff/complaints', ComplaintSummary.fromJson, query: {'cursor': cursor, 'limit': 20, if (openOnly) 'open': 'true'});

  Future<ComplaintDetail> staffAction(String id, Map<String, Object?> body) =>
      _api.postOne('/staff/complaints/$id/actions', ComplaintDetail.fromJson, body: body);
}
