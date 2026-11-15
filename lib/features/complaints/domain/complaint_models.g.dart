// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complaint_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComplaintPerson _$ComplaintPersonFromJson(Map<String, dynamic> json) =>
    ComplaintPerson(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );

ComplaintHostel _$ComplaintHostelFromJson(Map<String, dynamic> json) =>
    ComplaintHostel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
    );

ComplaintStaffRef _$ComplaintStaffRefFromJson(Map<String, dynamic> json) =>
    ComplaintStaffRef(
      id: json['id'] as String,
      name: json['name'] as String?,
      trade: json['trade'] as String?,
    );

ComplaintAvailability _$ComplaintAvailabilityFromJson(
  Map<String, dynamic> json,
) => ComplaintAvailability(
  from: DateTime.parse(json['from'] as String),
  to: DateTime.parse(json['to'] as String),
  allowEntryIfAway: json['allowEntryIfAway'] as bool? ?? false,
);

ComplaintVisit _$ComplaintVisitFromJson(Map<String, dynamic> json) =>
    ComplaintVisit(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );

ComplaintSummary _$ComplaintSummaryFromJson(Map<String, dynamic> json) =>
    ComplaintSummary(
      id: json['id'] as String,
      code: json['code'] as String,
      status: $enumDecode(
        _$ComplaintStatusEnumMap,
        json['status'],
        unknownValue: ComplaintStatus.unknown,
      ),
      category: $enumDecode(
        _$ComplaintCategoryEnumMap,
        json['category'],
        unknownValue: ComplaintCategory.unknown,
      ),
      priority: $enumDecode(
        _$ComplaintPriorityEnumMap,
        json['priority'],
        unknownValue: ComplaintPriority.unknown,
      ),
      title: json['title'] as String,
      location: json['location'] as String?,
      hostel: ComplaintHostel.fromJson(json['hostel'] as Map<String, dynamic>),
      unitLabel: json['unitLabel'] as String? ?? '',
      raisedBy: ComplaintPerson.fromJson(
        json['raisedBy'] as Map<String, dynamic>,
      ),
      assignedStaff: json['assignedStaff'] == null
          ? null
          : ComplaintStaffRef.fromJson(
              json['assignedStaff'] as Map<String, dynamic>,
            ),
      slaDueAt: DateTime.parse(json['slaDueAt'] as String),
      slaBreached: json['slaBreached'] as bool? ?? false,
      availability: json['availability'] == null
          ? null
          : ComplaintAvailability.fromJson(
              json['availability'] as Map<String, dynamic>,
            ),
      visit: json['visit'] == null
          ? null
          : ComplaintVisit.fromJson(json['visit'] as Map<String, dynamic>),
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt(),
      reopenCount: (json['reopenCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

const _$ComplaintStatusEnumMap = {
  ComplaintStatus.open: 'OPEN',
  ComplaintStatus.acknowledged: 'ACKNOWLEDGED',
  ComplaintStatus.assigned: 'ASSIGNED',
  ComplaintStatus.inProgress: 'IN_PROGRESS',
  ComplaintStatus.onHold: 'ON_HOLD',
  ComplaintStatus.resolved: 'RESOLVED',
  ComplaintStatus.closed: 'CLOSED',
  ComplaintStatus.reopened: 'REOPENED',
  ComplaintStatus.rejected: 'REJECTED',
  ComplaintStatus.unknown: 'UNKNOWN',
};

const _$ComplaintCategoryEnumMap = {
  ComplaintCategory.electrical: 'ELECTRICAL',
  ComplaintCategory.plumbing: 'PLUMBING',
  ComplaintCategory.carpentry: 'CARPENTRY',
  ComplaintCategory.cleaning: 'CLEANING',
  ComplaintCategory.food: 'FOOD',
  ComplaintCategory.wifi: 'WIFI',
  ComplaintCategory.security: 'SECURITY',
  ComplaintCategory.behaviour: 'BEHAVIOUR',
  ComplaintCategory.other: 'OTHER',
  ComplaintCategory.unknown: 'UNKNOWN',
};

const _$ComplaintPriorityEnumMap = {
  ComplaintPriority.low: 'LOW',
  ComplaintPriority.medium: 'MEDIUM',
  ComplaintPriority.high: 'HIGH',
  ComplaintPriority.urgent: 'URGENT',
  ComplaintPriority.unknown: 'UNKNOWN',
};

ComplaintPhoto _$ComplaintPhotoFromJson(Map<String, dynamic> json) =>
    ComplaintPhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      uploadedByRole:
          $enumDecodeNullable(
            _$ComplaintRoleEnumMap,
            json['uploadedByRole'],
            unknownValue: ComplaintRole.unknown,
          ) ??
          ComplaintRole.unknown,
    );

const _$ComplaintRoleEnumMap = {
  ComplaintRole.tenant: 'TENANT',
  ComplaintRole.owner: 'OWNER',
  ComplaintRole.staff: 'STAFF',
  ComplaintRole.admin: 'ADMIN',
  ComplaintRole.system: 'SYSTEM',
  ComplaintRole.unknown: 'UNKNOWN',
};

ComplaintComment _$ComplaintCommentFromJson(Map<String, dynamic> json) =>
    ComplaintComment(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorRole:
          $enumDecodeNullable(
            _$ComplaintRoleEnumMap,
            json['authorRole'],
            unknownValue: ComplaintRole.unknown,
          ) ??
          ComplaintRole.unknown,
      body: json['body'] as String,
      internal: json['internal'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

ComplaintHistoryEntry _$ComplaintHistoryEntryFromJson(
  Map<String, dynamic> json,
) => ComplaintHistoryEntry(
  id: json['id'] as String,
  toStatus: $enumDecode(
    _$ComplaintStatusEnumMap,
    json['toStatus'],
    unknownValue: ComplaintStatus.unknown,
  ),
  actorRole:
      $enumDecodeNullable(
        _$ComplaintRoleEnumMap,
        json['actorRole'],
        unknownValue: ComplaintRole.unknown,
      ) ??
      ComplaintRole.unknown,
  note: json['note'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

ComplaintDetail _$ComplaintDetailFromJson(
  Map<String, dynamic> json,
) => ComplaintDetail(
  id: json['id'] as String,
  code: json['code'] as String,
  status: $enumDecode(
    _$ComplaintStatusEnumMap,
    json['status'],
    unknownValue: ComplaintStatus.unknown,
  ),
  category: $enumDecode(
    _$ComplaintCategoryEnumMap,
    json['category'],
    unknownValue: ComplaintCategory.unknown,
  ),
  priority: $enumDecode(
    _$ComplaintPriorityEnumMap,
    json['priority'],
    unknownValue: ComplaintPriority.unknown,
  ),
  title: json['title'] as String,
  location: json['location'] as String?,
  hostel: ComplaintHostel.fromJson(json['hostel'] as Map<String, dynamic>),
  unitLabel: json['unitLabel'] as String? ?? '',
  raisedBy: ComplaintPerson.fromJson(json['raisedBy'] as Map<String, dynamic>),
  assignedStaff: json['assignedStaff'] == null
      ? null
      : ComplaintStaffRef.fromJson(
          json['assignedStaff'] as Map<String, dynamic>,
        ),
  slaDueAt: DateTime.parse(json['slaDueAt'] as String),
  slaBreached: json['slaBreached'] as bool? ?? false,
  availability: json['availability'] == null
      ? null
      : ComplaintAvailability.fromJson(
          json['availability'] as Map<String, dynamic>,
        ),
  visit: json['visit'] == null
      ? null
      : ComplaintVisit.fromJson(json['visit'] as Map<String, dynamic>),
  rating: (json['rating'] as num?)?.toInt(),
  reopenCount: (json['reopenCount'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  description: json['description'] as String? ?? '',
  resolvedAt: json['resolvedAt'] == null
      ? null
      : DateTime.parse(json['resolvedAt'] as String),
  resolutionNote: json['resolutionNote'] as String?,
  feedback: json['feedback'] as String?,
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => ComplaintPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  comments:
      (json['comments'] as List<dynamic>?)
          ?.map((e) => ComplaintComment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  history:
      (json['history'] as List<dynamic>?)
          ?.map(
            (e) => ComplaintHistoryEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  viewer: json['viewer'] as String? ?? 'TENANT',
  actions:
      (json['actions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

StaffMe _$StaffMeFromJson(Map<String, dynamic> json) => StaffMe(
  userId: json['userId'] as String,
  trade: json['trade'] as String,
  kind: json['kind'] as String? ?? 'OWN',
  status: json['status'] as String? ?? 'ACTIVE',
  employer: json['employer'] as String?,
  hostels:
      (json['hostels'] as List<dynamic>?)
          ?.map((e) => ComplaintHostel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  openJobs: (json['openJobs'] as num?)?.toInt() ?? 0,
);

StaffHostel _$StaffHostelFromJson(Map<String, dynamic> json) =>
    StaffHostel(id: json['id'] as String, name: json['name'] as String);

StaffMember _$StaffMemberFromJson(Map<String, dynamic> json) => StaffMember(
  userId: json['userId'] as String,
  name: json['name'] as String?,
  email: json['email'] as String? ?? '',
  phone: json['phone'] as String?,
  trade: json['trade'] as String,
  kind: json['kind'] as String? ?? 'OWN',
  status: json['status'] as String? ?? 'ACTIVE',
  hostels:
      (json['hostels'] as List<dynamic>?)
          ?.map((e) => StaffHostel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  openJobs: (json['openJobs'] as num?)?.toInt() ?? 0,
);

StaffInviteItem _$StaffInviteItemFromJson(Map<String, dynamic> json) =>
    StaffInviteItem(
      id: json['id'] as String,
      email: json['email'] as String,
      trade: json['trade'] as String,
      hostels:
          (json['hostels'] as List<dynamic>?)
              ?.map((e) => StaffHostel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

OwnerTeam _$OwnerTeamFromJson(Map<String, dynamic> json) => OwnerTeam(
  staff:
      (json['staff'] as List<dynamic>?)
          ?.map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  invites:
      (json['invites'] as List<dynamic>?)
          ?.map((e) => StaffInviteItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

VendorItem _$VendorItemFromJson(Map<String, dynamic> json) => VendorItem(
  userId: json['userId'] as String,
  name: json['name'] as String?,
  trade: json['trade'] as String,
  hostels:
      (json['hostels'] as List<dynamic>?)
          ?.map((e) => StaffHostel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
