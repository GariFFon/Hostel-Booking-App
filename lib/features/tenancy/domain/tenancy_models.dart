import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/format.dart';
import '../../hostels/domain/enums.dart';

part 'tenancy_models.g.dart';

/// Backend enums for long-term stays. Each has an `unknown` member so a value added later renders neutrally instead of crashing.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum TenancyStatus {
  invited('Invited'),
  pendingMoveIn('Awaiting move-in'),
  active('Living here'),
  notice('On notice'),
  ended('Ended'),
  cancelled('Cancelled'),
  unknown('Stay');

  const TenancyStatus(this.label);
  final String label;

  /// Still holds a bed.
  bool get isLive => this == invited || this == pendingMoveIn || this == active || this == notice;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ApplicationStatus {
  requested('Requested'),
  approved('Approved'),
  rejected('Declined'),
  withdrawn('Withdrawn'),
  expired('Expired'),
  unknown('Request');

  const ApplicationStatus(this.label);
  final String label;
}

@JsonSerializable(createToJson: false)
class TenancyPerson {
  const TenancyPerson({required this.id, this.name, this.email = '', this.phone});
  final String id;
  final String? name;
  final String email;
  final String? phone;

  String get display => (name != null && name!.trim().isNotEmpty) ? name! : email;

  factory TenancyPerson.fromJson(Map<String, dynamic> json) => _$TenancyPersonFromJson(json);
}

@JsonSerializable(createToJson: false)
class TenancyHostelRef {
  const TenancyHostelRef({required this.id, this.slug = '', required this.name, this.city = '', this.addressLine = ''});
  final String id;
  final String slug;
  final String name;
  final String city;
  final String addressLine;

  factory TenancyHostelRef.fromJson(Map<String, dynamic> json) => _$TenancyHostelRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class TenancyRoomRef {
  const TenancyRoomRef({required this.id, required this.name, this.kind = RoomKind.dorm});
  final String id;
  final String name;
  @JsonKey(unknownEnumValue: RoomKind.unknown)
  final RoomKind kind;

  factory TenancyRoomRef.fromJson(Map<String, dynamic> json) => _$TenancyRoomRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class TenancyUnit {
  const TenancyUnit({required this.id, required this.label, this.floor});
  final String id;
  final String label;
  final int? floor;

  factory TenancyUnit.fromJson(Map<String, dynamic> json) => _$TenancyUnitFromJson(json);
}

@JsonSerializable(createToJson: false)
class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});
  final String name;
  final String phone;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => _$EmergencyContactFromJson(json);
}

/// Notice given by the tenant or the owner on a running stay.
@JsonSerializable(createToJson: false)
class TenancyNotice {
  const TenancyNotice({required this.givenAt, this.by = 'TENANT', this.reason, this.moveOutDate});
  final DateTime givenAt;

  /// TENANT or OWNER: only that side can withdraw it.
  final String by;
  final String? reason;
  final String? moveOutDate;

  bool get byTenant => by == 'TENANT';
  DateTime? get moveOut => moveOutDate == null ? null : parseDate(moveOutDate!);

  factory TenancyNotice.fromJson(Map<String, dynamic> json) => _$TenancyNoticeFromJson(json);
}

/// Where the deposit settlement stands, as shown on the stay.
@JsonSerializable(createToJson: false)
class TenancySettlementRef {
  const TenancySettlementRef({required this.id, this.status = 'DRAFT', this.refundPaise = 0});
  final String id;

  /// DRAFT, PROPOSED, DISPUTED, AGREED or COMPLETED.
  final String status;
  final int refundPaise;

  factory TenancySettlementRef.fromJson(Map<String, dynamic> json) => _$TenancySettlementRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class DepositInfo {
  const DepositInfo({this.status = 'NONE', this.receivedAt, this.method, this.reference});

  /// NONE (nothing due), DUE or RECEIVED.
  final String status;
  final String? receivedAt;
  final String? method;
  final String? reference;

  bool get isDue => status == 'DUE';
  bool get isReceived => status == 'RECEIVED';

  factory DepositInfo.fromJson(Map<String, dynamic> json) => _$DepositInfoFromJson(json);
}

@JsonSerializable(createToJson: false)
class Tenancy {
  const Tenancy({
    required this.id,
    required this.code,
    this.status = TenancyStatus.unknown,
    required this.hostel,
    required this.roomType,
    required this.unit,
    this.tenant,
    this.inviteEmail,
    required this.startDate,
    this.endDate,
    required this.rentPaise,
    this.depositPaise = 0,
    this.dueDay = 1,
    this.graceDays = 5,
    this.noticeDays = 30,
    this.deposit = const DepositInfo(),
    this.depositWarning,
    this.emergencyContact,
    this.cancelReason,
    this.notice,
    this.movedOutAt,
    this.settlement,
    this.version = 1,
    this.actions = const [],
  });

  final String id;
  final String code;
  @JsonKey(unknownEnumValue: TenancyStatus.unknown)
  final TenancyStatus status;
  final TenancyHostelRef hostel;
  final TenancyRoomRef roomType;
  final TenancyUnit unit;
  final TenancyPerson? tenant;
  final String? inviteEmail;
  final String startDate;
  final String? endDate;
  final int rentPaise;
  final int depositPaise;
  final int dueDay;
  final int graceDays;
  final int noticeDays;
  final DepositInfo deposit;
  final String? depositWarning;
  final EmergencyContact? emergencyContact;
  final String? cancelReason;
  final TenancyNotice? notice;
  final DateTime? movedOutAt;
  final TenancySettlementRef? settlement;
  final int version;

  /// What the server lets the current viewer do: `accept`, `decline`, `edit`, `record_deposit`, `activate`, `cancel`,
  /// `give_notice`, `withdraw_notice`, `pay_deposit`, `serve_notice`, `move_out`, `settle`.
  final List<String> actions;

  DateTime get start => parseDate(startDate);
  bool can(String action) => actions.contains(action);
  String get tenantLabel => tenant?.display ?? inviteEmail ?? 'Tenant';

  factory Tenancy.fromJson(Map<String, dynamic> json) => _$TenancyFromJson(json);
}

@JsonSerializable(createToJson: false)
class TenancyApplication {
  const TenancyApplication({
    required this.id,
    this.status = ApplicationStatus.unknown,
    required this.hostel,
    required this.roomType,
    required this.applicant,
    required this.moveInDate,
    this.tenureMonths,
    this.occupation,
    this.message,
    required this.emergencyContact,
    this.decisionNote,
    this.tenancyId,
    this.actions = const [],
  });

  final String id;
  @JsonKey(unknownEnumValue: ApplicationStatus.unknown)
  final ApplicationStatus status;
  final TenancyHostelRef hostel;
  final TenancyRoomRef roomType;
  final TenancyPerson applicant;
  final String moveInDate;
  final int? tenureMonths;
  final String? occupation;
  final String? message;
  final EmergencyContact emergencyContact;
  final String? decisionNote;
  final String? tenancyId;

  /// `withdraw` for the applicant, `approve` / `reject` for the owner.
  final List<String> actions;

  DateTime get moveIn => parseDate(moveInDate);
  bool can(String action) => actions.contains(action);

  factory TenancyApplication.fromJson(Map<String, dynamic> json) => _$TenancyApplicationFromJson(json);
}

@JsonSerializable(createToJson: false)
class TermsRoom {
  const TermsRoom({
    required this.roomTypeId,
    required this.name,
    this.kind = RoomKind.dorm,
    this.gender = RoomGender.mixed,
    required this.rentPaise,
    this.freeUnits = 0,
  });
  final String roomTypeId;
  final String name;
  @JsonKey(unknownEnumValue: RoomKind.unknown)
  final RoomKind kind;
  @JsonKey(unknownEnumValue: RoomGender.unknown)
  final RoomGender gender;
  final int rentPaise;
  final int freeUnits;

  factory TermsRoom.fromJson(Map<String, dynamic> json) => _$TermsRoomFromJson(json);
}

/// What a student sees before asking for a bed.
@JsonSerializable(createToJson: false)
class TenancyTerms {
  const TenancyTerms({this.depositMonths = 2, this.noticeDays = 30, this.rentDueDay = 1, this.rentGraceDays = 5, this.rooms = const []});
  final int depositMonths;
  final int noticeDays;
  final int rentDueDay;
  final int rentGraceDays;
  final List<TermsRoom> rooms;

  int get freeUnits => rooms.fold(0, (n, r) => n + r.freeUnits);

  factory TenancyTerms.fromJson(Map<String, dynamic> json) => _$TenancyTermsFromJson(json);
}

/// A bed or room nobody holds, offered to the owner when approving a request or adding a tenant.
@JsonSerializable(createToJson: false)
class FreeUnit {
  const FreeUnit({required this.id, required this.label, this.floor});
  final String id;
  final String label;
  final int? floor;

  String get display => floor == null ? label : '$label · floor $floor';

  factory FreeUnit.fromJson(Map<String, dynamic> json) => _$FreeUnitFromJson(json);
}

/// A room type of one of the owner's properties (just what the add-tenant sheet needs).
@JsonSerializable(createToJson: false)
class OwnerRoom {
  const OwnerRoom({required this.id, required this.name, this.basePricePaise = 0});
  final String id;
  final String name;
  final int basePricePaise;

  factory OwnerRoom.fromJson(Map<String, dynamic> json) => _$OwnerRoomFromJson(json);
}

/// "1st", "2nd", "3rd", "4th"... for a day of the month.
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum SettlementStatus {
  draft('Draft'),
  proposed('Waiting for the tenant'),
  disputed('Disputed'),
  agreed('Agreed'),
  completed('Settled'),
  unknown('Settlement');

  const SettlementStatus(this.label);
  final String label;
}

@JsonSerializable(createToJson: false)
class SettlementLine {
  const SettlementLine({required this.id, this.type = 'OTHER', required this.description, required this.amountPaise, this.invoiceId});
  final String id;
  final String? invoiceId;

  /// UNPAID_RENT, DAMAGE, CLEANING, UTILITIES or OTHER.
  final String type;
  final String description;
  final int amountPaise;

  String get typeLabel => humanize(type);

  factory SettlementLine.fromJson(Map<String, dynamic> json) => _$SettlementLineFromJson(json);
}

@JsonSerializable(createToJson: false)
class SettlementProof {
  const SettlementProof({required this.id, required this.url});
  final String id;
  final String url;

  factory SettlementProof.fromJson(Map<String, dynamic> json) => _$SettlementProofFromJson(json);
}

/// An invoice with rent still owed: unpaid rent deductions are picked from these.
@JsonSerializable(createToJson: false)
class OpenInvoiceRef {
  const OpenInvoiceRef({required this.id, required this.number, required this.balancePaise});
  final String id;
  final String number;
  final int balancePaise;

  factory OpenInvoiceRef.fromJson(Map<String, dynamic> json) => _$OpenInvoiceRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class SettlementPayout {
  const SettlementPayout({this.online = false, this.method, this.reference});
  final bool online;
  final String? method;
  final String? reference;

  factory SettlementPayout.fromJson(Map<String, dynamic> json) => _$SettlementPayoutFromJson(json);
}

/// What is deducted from a deposit when a stay ends, and what comes back.
@JsonSerializable(createToJson: false)
class DepositSettlement {
  const DepositSettlement({
    required this.id,
    required this.tenancyId,
    this.status = SettlementStatus.unknown,
    required this.depositPaise,
    this.deductionsPaise = 0,
    required this.refundPaise,
    this.note,
    this.disputeNote,
    this.respondBy,
    this.autoAgreed = false,
    this.payout = const SettlementPayout(),
    this.deductions = const [],
    this.proofs = const [],
    this.openInvoices = const [],
    this.actions = const [],
  });

  final String id;
  final String tenancyId;
  @JsonKey(unknownEnumValue: SettlementStatus.unknown)
  final SettlementStatus status;
  final int depositPaise;
  final int deductionsPaise;
  final int refundPaise;
  final String? note;
  final String? disputeNote;
  final DateTime? respondBy;
  final bool autoAgreed;
  final SettlementPayout payout;
  final List<SettlementLine> deductions;
  final List<SettlementProof> proofs;

  /// Owner only, while it can be edited: invoices with rent still owed.
  final List<OpenInvoiceRef> openInvoices;

  /// `edit`, `add_proof`, `propose`, `retract`, `accept`, `dispute`, `record_payout`, `resolve`.
  final List<String> actions;

  bool can(String action) => actions.contains(action);

  factory DepositSettlement.fromJson(Map<String, dynamic> json) => _$DepositSettlementFromJson(json);
}
