import 'package:dio/dio.dart' show MultipartFile;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/util/photo_picker.dart';
import '../../../core/network/envelope.dart';
import '../domain/tenancy_models.dart';

/// Long-term stays: a student's requests and tenancies, and the owner's side of both.
class TenancyRepository {
  TenancyRepository(this._api);

  final ApiClient _api;

  // ── student ──
  Future<TenancyTerms> terms(String idOrSlug) => _api.getOne('/hostels/$idOrSlug/tenancy-terms', TenancyTerms.fromJson, auth: false);

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
  }) => _api.postOne(
    '/hostels/$hostelId/tenancy-applications',
    TenancyApplication.fromJson,
    body: {
      'roomTypeId': roomTypeId,
      'moveInDate': moveInDate,
      'tenureMonths': ?tenureMonths,
      'gender': ?gender,
      if (occupation != null && occupation.trim().isNotEmpty) 'occupation': occupation.trim(),
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      'emergencyContactName': emergencyContactName.trim(),
      'emergencyContactPhone': emergencyContactPhone.replaceAll(RegExp(r'[\s-]'), ''),
    },
  );

  Future<Paged<TenancyApplication>> myApplications({String? cursor}) =>
      _api.getPage('/me/tenancy-applications', TenancyApplication.fromJson, query: {'cursor': cursor, 'limit': 20});

  Future<TenancyApplication> withdraw(String id) => _api.postOne('/me/tenancy-applications/$id/withdraw', TenancyApplication.fromJson);

  Future<Paged<Tenancy>> myTenancies({String? cursor}) => _api.getPage('/me/tenancies', Tenancy.fromJson, query: {'cursor': cursor, 'limit': 20});

  /// Gives notice: [moveOutDate] is the day the tenant will have moved out (at least the stay's notice period away).
  Future<Tenancy> giveNotice(String id, {required String moveOutDate, String? reason}) => _api.postOne(
    '/me/tenancies/$id/notice',
    Tenancy.fromJson,
    body: {'moveOutDate': moveOutDate, if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
  );

  Future<Tenancy> withdrawNotice(String id) => _api.postOne('/me/tenancies/$id/notice/withdraw', Tenancy.fromJson);

  Future<DepositSettlement> mySettlement(String tenancyId) => _api.getOne('/me/tenancies/$tenancyId/settlement', DepositSettlement.fromJson);

  Future<DepositSettlement> acceptSettlement(String tenancyId) =>
      _api.postOne('/me/tenancies/$tenancyId/settlement/accept', DepositSettlement.fromJson);

  Future<DepositSettlement> disputeSettlement(String tenancyId, String note) =>
      _api.postOne('/me/tenancies/$tenancyId/settlement/dispute', DepositSettlement.fromJson, body: {'note': note.trim()});

  Future<Tenancy> accept(String id) => _api.postOne('/me/tenancies/$id/accept', Tenancy.fromJson);

  Future<Tenancy> decline(String id) => _api.postOne('/me/tenancies/$id/decline', Tenancy.fromJson);

  // ── owner ──
  Future<Paged<TenancyApplication>> hostApplications({String? cursor}) =>
      _api.getPage('/owner/tenancy-applications', TenancyApplication.fromJson, query: {'status': 'REQUESTED', 'cursor': cursor, 'limit': 20});

  Future<TenancyApplication> approve(String id, {String? unitId, int? rentPaise, int? depositPaise, String? startDate}) => _api.postOne(
    '/owner/tenancy-applications/$id/approve',
    TenancyApplication.fromJson,
    body: {'unitId': ?unitId, 'rentPaise': ?rentPaise, 'depositPaise': ?depositPaise, 'startDate': ?startDate},
  );

  Future<List<FreeUnit>> freeUnits(String roomTypeId) => _api.getList('/owner/room-types/$roomTypeId/free-units', FreeUnit.fromJson);

  Future<List<OwnerRoom>> rooms(String hostelId) => _api.getList('/owner/hostels/$hostelId/room-types', OwnerRoom.fromJson);

  /// Adds or invites a tenant by email (someone who already lives there, or applied off-platform).
  Future<Tenancy> createTenancy({
    required String roomTypeId,
    String? unitId,
    required String tenantEmail,
    required String startDate,
    int? rentPaise,
    int? depositPaise,
    String? depositMethod,
  }) => _api.postOne(
    '/owner/tenancies',
    Tenancy.fromJson,
    body: {
      'roomTypeId': roomTypeId,
      'unitId': ?unitId,
      'tenantEmail': tenantEmail.trim(),
      'startDate': startDate,
      'rentPaise': ?rentPaise,
      'depositPaise': ?depositPaise,
      if (depositMethod != null) 'depositReceived': {'method': depositMethod},
    },
  );

  Future<TenancyApplication> reject(String id, String reason) =>
      _api.postOne('/owner/tenancy-applications/$id/reject', TenancyApplication.fromJson, body: {'reason': reason.trim()});

  Future<Paged<Tenancy>> hostTenancies({String? status, String? cursor}) =>
      _api.getPage('/owner/tenancies', Tenancy.fromJson, query: {'status': status, 'cursor': cursor, 'limit': 20});

  Future<Tenancy> recordDeposit(String id, {required String method, String? reference}) => _api.postOne(
    '/owner/tenancies/$id/deposit',
    Tenancy.fromJson,
    body: {'method': method, if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim()},
  );

  /// A five-minute link to the security-deposit receipt as a PDF.
  Future<String> depositReceiptLink(String tenancyId, {bool host = false}) async {
    final e = await _api.post('/${host ? 'owner' : 'me'}/tenancies/$tenancyId/deposit-receipt-link');
    return asMap(e.data)['url'] as String;
  }

  /// Saves the itemised deductions (replacing the old list). Each line: `type`, `description`, `amountPaise`, and `invoiceId` for unpaid rent.
  Future<DepositSettlement> saveSettlement(String tenancyId, {required List<Map<String, Object?>> deductions, String? note}) => _api.putOne(
    '/owner/tenancies/$tenancyId/settlement',
    DepositSettlement.fromJson,
    body: {'deductions': deductions, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  /// Uploads one evidence photo and attaches it: the server signs the upload, the phone sends the file straight to the image host,
  /// and the server re-checks it before attaching. Returns the settlement as it now stands.
  Future<DepositSettlement> addSettlementProof(String tenancyId, PickedPhoto photo) async {
    final sig = asMap((await _api.post('/uploads/signature', body: {'purpose': 'DEPOSIT_PROOF', 'tenancyId': tenancyId})).data);
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
    return _api.postOne('/owner/tenancies/$tenancyId/settlement/proofs', DepositSettlement.fromJson, body: {'publicId': sig['publicId']});
  }

  Future<DepositSettlement> removeSettlementProof(String tenancyId, String proofId) =>
      _api.deleteOne('/owner/tenancies/$tenancyId/settlement/proofs/$proofId', DepositSettlement.fromJson);

  Future<Tenancy> serveNotice(String id, {required String moveOutDate, String? reason}) => _api.postOne(
    '/owner/tenancies/$id/notice',
    Tenancy.fromJson,
    body: {'moveOutDate': moveOutDate, if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
  );

  Future<Tenancy> ownerWithdrawNotice(String id) => _api.postOne('/owner/tenancies/$id/notice/withdraw', Tenancy.fromJson);

  Future<Tenancy> moveOut(String id, {String? movedOutOn, String? note}) => _api.postOne(
    '/owner/tenancies/$id/move-out',
    Tenancy.fromJson,
    body: {'movedOutOn': ?movedOutOn, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  Future<DepositSettlement> hostSettlement(String tenancyId) => _api.getOne('/owner/tenancies/$tenancyId/settlement', DepositSettlement.fromJson);

  /// Sends the settlement as it stands (unpaid rent pre-filled) to the tenant.
  Future<DepositSettlement> proposeSettlement(String tenancyId) =>
      _api.postOne('/owner/tenancies/$tenancyId/settlement/propose', DepositSettlement.fromJson);

  Future<DepositSettlement> retractSettlement(String tenancyId) =>
      _api.postOne('/owner/tenancies/$tenancyId/settlement/retract', DepositSettlement.fromJson);

  Future<DepositSettlement> recordPayout(String tenancyId, {required String method, String? reference}) => _api.postOne(
    '/owner/tenancies/$tenancyId/settlement/payout',
    DepositSettlement.fromJson,
    body: {'method': method, if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim()},
  );

  Future<Tenancy> activate(String id) => _api.postOne('/owner/tenancies/$id/activate', Tenancy.fromJson);

  Future<Tenancy> cancel(String id, String reason) => _api.postOne('/owner/tenancies/$id/cancel', Tenancy.fromJson, body: {'reason': reason.trim()});
}
