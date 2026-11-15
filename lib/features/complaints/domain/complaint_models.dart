import 'package:json_annotation/json_annotation.dart';

part 'complaint_models.g.dart';

/// Backend enums for complaints. Each has an `unknown` member so a value added later renders neutrally instead of crashing.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ComplaintStatus {
  open('Open'),
  acknowledged('Seen by owner'),
  assigned('Assigned'),
  inProgress('In progress'),
  onHold('On hold'),
  resolved('Resolved'),
  closed('Closed'),
  reopened('Reopened'),
  rejected('Declined'),
  unknown('Complaint');

  const ComplaintStatus(this.label);
  final String label;

  /// Still needs someone to act.
  bool get isOpen => this != resolved && this != closed && this != rejected && this != unknown;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ComplaintPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent'),
  unknown('Normal');

  const ComplaintPriority(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ComplaintCategory {
  electrical('Electrical'),
  plumbing('Plumbing'),
  carpentry('Carpentry'),
  cleaning('Cleaning'),
  food('Food'),
  wifi('Wi-Fi'),
  security('Security'),
  behaviour('Behaviour'),
  other('Other'),
  unknown('Other');

  const ComplaintCategory(this.label);
  final String label;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum ComplaintRole {
  tenant('tenant'),
  owner('owner'),
  staff('staff'),
  admin('admin'),
  system('the system'),
  unknown('someone');

  const ComplaintRole(this.label);
  final String label;
}

@JsonSerializable(createToJson: false)
class ComplaintPerson {
  const ComplaintPerson({required this.id, this.name, this.phone, this.email});
  final String id;
  final String? name;
  final String? phone;
  final String? email;

  factory ComplaintPerson.fromJson(Map<String, dynamic> json) => _$ComplaintPersonFromJson(json);
}

@JsonSerializable(createToJson: false)
class ComplaintHostel {
  const ComplaintHostel({required this.id, required this.name, this.city = ''});
  final String id;
  final String name;
  final String city;

  factory ComplaintHostel.fromJson(Map<String, dynamic> json) => _$ComplaintHostelFromJson(json);
}

@JsonSerializable(createToJson: false)
class ComplaintStaffRef {
  const ComplaintStaffRef({required this.id, this.name, this.trade});
  final String id;
  final String? name;
  final String? trade;

  String get display => (name != null && name!.trim().isNotEmpty) ? name! : 'Staff';

  factory ComplaintStaffRef.fromJson(Map<String, dynamic> json) => _$ComplaintStaffRefFromJson(json);
}

/// When the tenant is free to let someone in.
@JsonSerializable(createToJson: false)
class ComplaintAvailability {
  const ComplaintAvailability({required this.from, required this.to, this.allowEntryIfAway = false});
  final DateTime from;
  final DateTime to;
  final bool allowEntryIfAway;

  factory ComplaintAvailability.fromJson(Map<String, dynamic> json) => _$ComplaintAvailabilityFromJson(json);
}

/// The visit slot staff booked inside that window.
@JsonSerializable(createToJson: false)
class ComplaintVisit {
  const ComplaintVisit({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  factory ComplaintVisit.fromJson(Map<String, dynamic> json) => _$ComplaintVisitFromJson(json);
}

/// One row in a list.
@JsonSerializable(createToJson: false)
class ComplaintSummary {
  const ComplaintSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.category,
    required this.priority,
    required this.title,
    this.location,
    required this.hostel,
    this.unitLabel = '',
    required this.raisedBy,
    this.assignedStaff,
    required this.slaDueAt,
    this.slaBreached = false,
    this.availability,
    this.visit,
    this.mediaCount = 0,
    this.commentCount = 0,
    this.rating,
    this.reopenCount = 0,
    required this.createdAt,
  });

  final String id;
  final String code;
  @JsonKey(unknownEnumValue: ComplaintStatus.unknown)
  final ComplaintStatus status;
  @JsonKey(unknownEnumValue: ComplaintCategory.unknown)
  final ComplaintCategory category;
  @JsonKey(unknownEnumValue: ComplaintPriority.unknown)
  final ComplaintPriority priority;
  final String title;
  final String? location;
  final ComplaintHostel hostel;
  final String unitLabel;
  final ComplaintPerson raisedBy;
  final ComplaintStaffRef? assignedStaff;
  final DateTime slaDueAt;
  final bool slaBreached;
  final ComplaintAvailability? availability;
  final ComplaintVisit? visit;
  final int mediaCount;
  final int commentCount;
  final int? rating;
  final int reopenCount;
  final DateTime createdAt;

  factory ComplaintSummary.fromJson(Map<String, dynamic> json) => _$ComplaintSummaryFromJson(json);
}

@JsonSerializable(createToJson: false)
class ComplaintPhoto {
  const ComplaintPhoto({required this.id, required this.url, this.uploadedByRole = ComplaintRole.unknown});
  final String id;
  final String url;
  @JsonKey(unknownEnumValue: ComplaintRole.unknown)
  final ComplaintRole uploadedByRole;

  factory ComplaintPhoto.fromJson(Map<String, dynamic> json) => _$ComplaintPhotoFromJson(json);
}

@JsonSerializable(createToJson: false)
class ComplaintComment {
  const ComplaintComment({
    required this.id,
    required this.authorName,
    this.authorRole = ComplaintRole.unknown,
    required this.body,
    this.internal = false,
    required this.createdAt,
  });
  final String id;
  final String authorName;
  @JsonKey(unknownEnumValue: ComplaintRole.unknown)
  final ComplaintRole authorRole;
  final String body;
  final bool internal;
  final DateTime createdAt;

  factory ComplaintComment.fromJson(Map<String, dynamic> json) => _$ComplaintCommentFromJson(json);
}

@JsonSerializable(createToJson: false)
class ComplaintHistoryEntry {
  const ComplaintHistoryEntry({required this.id, required this.toStatus, this.actorRole = ComplaintRole.unknown, this.note, required this.createdAt});
  final String id;
  @JsonKey(unknownEnumValue: ComplaintStatus.unknown)
  final ComplaintStatus toStatus;
  @JsonKey(unknownEnumValue: ComplaintRole.unknown)
  final ComplaintRole actorRole;
  final String? note;
  final DateTime createdAt;

  factory ComplaintHistoryEntry.fromJson(Map<String, dynamic> json) => _$ComplaintHistoryEntryFromJson(json);
}

/// A complaint with its whole story. `actions` is exactly what the server lets this person do right now.
@JsonSerializable(createToJson: false)
class ComplaintDetail {
  const ComplaintDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.category,
    required this.priority,
    required this.title,
    this.location,
    required this.hostel,
    this.unitLabel = '',
    required this.raisedBy,
    this.assignedStaff,
    required this.slaDueAt,
    this.slaBreached = false,
    this.availability,
    this.visit,
    this.rating,
    this.reopenCount = 0,
    required this.createdAt,
    this.description = '',
    this.resolvedAt,
    this.resolutionNote,
    this.feedback,
    this.media = const [],
    this.comments = const [],
    this.history = const [],
    this.viewer = 'TENANT',
    this.actions = const [],
  });

  final String id;
  final String code;
  @JsonKey(unknownEnumValue: ComplaintStatus.unknown)
  final ComplaintStatus status;
  @JsonKey(unknownEnumValue: ComplaintCategory.unknown)
  final ComplaintCategory category;
  @JsonKey(unknownEnumValue: ComplaintPriority.unknown)
  final ComplaintPriority priority;
  final String title;
  final String? location;
  final ComplaintHostel hostel;
  final String unitLabel;
  final ComplaintPerson raisedBy;
  final ComplaintStaffRef? assignedStaff;
  final DateTime slaDueAt;
  final bool slaBreached;
  final ComplaintAvailability? availability;
  final ComplaintVisit? visit;
  final int? rating;
  final int reopenCount;
  final DateTime createdAt;
  final String description;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? feedback;
  final List<ComplaintPhoto> media;
  final List<ComplaintComment> comments;
  final List<ComplaintHistoryEntry> history;
  final String viewer;
  final List<String> actions;

  bool can(String action) => actions.contains(action);

  factory ComplaintDetail.fromJson(Map<String, dynamic> json) => _$ComplaintDetailFromJson(json);
}

/// A maintenance person's own profile (`/staff/me`).
@JsonSerializable(createToJson: false)
class StaffMe {
  const StaffMe({
    required this.userId,
    required this.trade,
    this.kind = 'OWN',
    this.status = 'ACTIVE',
    this.employer,
    this.hostels = const [],
    this.openJobs = 0,
  });
  final String userId;
  final String trade;
  final String kind;
  final String status;
  final String? employer;
  final List<ComplaintHostel> hostels;
  final int openJobs;

  bool get active => status == 'ACTIVE';

  factory StaffMe.fromJson(Map<String, dynamic> json) => _$StaffMeFromJson(json);
}

/// A property reference inside a staff row.
@JsonSerializable(createToJson: false)
class StaffHostel {
  const StaffHostel({required this.id, required this.name});
  final String id;
  final String name;

  factory StaffHostel.fromJson(Map<String, dynamic> json) => _$StaffHostelFromJson(json);
}

/// Trades a maintenance person can have. `OTHER` is for anything not listed.
const staffTrades = ['ELECTRICIAN', 'PLUMBER', 'CARPENTER', 'CLEANER', 'COOK', 'SECURITY', 'WARDEN', 'NETWORK', 'OTHER'];

/// One person on an owner's maintenance team (their own staff, or a platform vendor they engaged).
@JsonSerializable(createToJson: false)
class StaffMember {
  const StaffMember({
    required this.userId,
    this.name,
    this.email = '',
    this.phone,
    required this.trade,
    this.kind = 'OWN',
    this.status = 'ACTIVE',
    this.hostels = const [],
    this.openJobs = 0,
  });
  final String userId;
  final String? name;
  final String email;
  final String? phone;
  final String trade;

  /// OWN = this owner's own staff; VENDOR = a platform vendor.
  final String kind;
  final String status;
  final List<StaffHostel> hostels;
  final int openJobs;

  bool get active => status == 'ACTIVE';
  bool get isVendor => kind == 'VENDOR';
  String get display => (name != null && name!.trim().isNotEmpty) ? name! : email;

  factory StaffMember.fromJson(Map<String, dynamic> json) => _$StaffMemberFromJson(json);
}

/// An invitation that has been sent and not yet accepted.
@JsonSerializable(createToJson: false)
class StaffInviteItem {
  const StaffInviteItem({required this.id, required this.email, required this.trade, this.hostels = const [], required this.expiresAt});
  final String id;
  final String email;
  final String trade;
  final List<StaffHostel> hostels;
  final DateTime expiresAt;

  factory StaffInviteItem.fromJson(Map<String, dynamic> json) => _$StaffInviteItemFromJson(json);
}

@JsonSerializable(createToJson: false)
class OwnerTeam {
  const OwnerTeam({this.staff = const [], this.invites = const []});
  final List<StaffMember> staff;
  final List<StaffInviteItem> invites;

  factory OwnerTeam.fromJson(Map<String, dynamic> json) => _$OwnerTeamFromJson(json);
}

/// A platform vendor an owner can engage.
@JsonSerializable(createToJson: false)
class VendorItem {
  const VendorItem({required this.userId, this.name, required this.trade, this.hostels = const []});
  final String userId;
  final String? name;
  final String trade;

  /// Where THIS owner has engaged them.
  final List<StaffHostel> hostels;

  String get display => (name != null && name!.trim().isNotEmpty) ? name! : 'Vendor';

  factory VendorItem.fromJson(Map<String, dynamic> json) => _$VendorItemFromJson(json);
}
