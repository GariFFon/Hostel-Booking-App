// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenancy_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TenancyPerson _$TenancyPersonFromJson(Map<String, dynamic> json) =>
    TenancyPerson(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
    );

TenancyHostelRef _$TenancyHostelRefFromJson(Map<String, dynamic> json) =>
    TenancyHostelRef(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
    );

TenancyRoomRef _$TenancyRoomRefFromJson(Map<String, dynamic> json) =>
    TenancyRoomRef(
      id: json['id'] as String,
      name: json['name'] as String,
      kind:
          $enumDecodeNullable(
            _$RoomKindEnumMap,
            json['kind'],
            unknownValue: RoomKind.unknown,
          ) ??
          RoomKind.dorm,
    );

const _$RoomKindEnumMap = {
  RoomKind.dorm: 'DORM',
  RoomKind.private: 'PRIVATE',
  RoomKind.unknown: 'UNKNOWN',
};

TenancyUnit _$TenancyUnitFromJson(Map<String, dynamic> json) => TenancyUnit(
  id: json['id'] as String,
  label: json['label'] as String,
  floor: (json['floor'] as num?)?.toInt(),
);

EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );

TenancyNotice _$TenancyNoticeFromJson(Map<String, dynamic> json) =>
    TenancyNotice(
      givenAt: DateTime.parse(json['givenAt'] as String),
      by: json['by'] as String? ?? 'TENANT',
      reason: json['reason'] as String?,
      moveOutDate: json['moveOutDate'] as String?,
    );

TenancySettlementRef _$TenancySettlementRefFromJson(
  Map<String, dynamic> json,
) => TenancySettlementRef(
  id: json['id'] as String,
  status: json['status'] as String? ?? 'DRAFT',
  refundPaise: (json['refundPaise'] as num?)?.toInt() ?? 0,
);

DepositInfo _$DepositInfoFromJson(Map<String, dynamic> json) => DepositInfo(
  status: json['status'] as String? ?? 'NONE',
  receivedAt: json['receivedAt'] as String?,
  method: json['method'] as String?,
  reference: json['reference'] as String?,
);

Tenancy _$TenancyFromJson(Map<String, dynamic> json) => Tenancy(
  id: json['id'] as String,
  code: json['code'] as String,
  status:
      $enumDecodeNullable(
        _$TenancyStatusEnumMap,
        json['status'],
        unknownValue: TenancyStatus.unknown,
      ) ??
      TenancyStatus.unknown,
  hostel: TenancyHostelRef.fromJson(json['hostel'] as Map<String, dynamic>),
  roomType: TenancyRoomRef.fromJson(json['roomType'] as Map<String, dynamic>),
  unit: TenancyUnit.fromJson(json['unit'] as Map<String, dynamic>),
  tenant: json['tenant'] == null
      ? null
      : TenancyPerson.fromJson(json['tenant'] as Map<String, dynamic>),
  inviteEmail: json['inviteEmail'] as String?,
  startDate: json['startDate'] as String,
  endDate: json['endDate'] as String?,
  rentPaise: (json['rentPaise'] as num).toInt(),
  depositPaise: (json['depositPaise'] as num?)?.toInt() ?? 0,
  dueDay: (json['dueDay'] as num?)?.toInt() ?? 1,
  graceDays: (json['graceDays'] as num?)?.toInt() ?? 5,
  noticeDays: (json['noticeDays'] as num?)?.toInt() ?? 30,
  deposit: json['deposit'] == null
      ? const DepositInfo()
      : DepositInfo.fromJson(json['deposit'] as Map<String, dynamic>),
  depositWarning: json['depositWarning'] as String?,
  emergencyContact: json['emergencyContact'] == null
      ? null
      : EmergencyContact.fromJson(
          json['emergencyContact'] as Map<String, dynamic>,
        ),
  cancelReason: json['cancelReason'] as String?,
  notice: json['notice'] == null
      ? null
      : TenancyNotice.fromJson(json['notice'] as Map<String, dynamic>),
  movedOutAt: json['movedOutAt'] == null
      ? null
      : DateTime.parse(json['movedOutAt'] as String),
  settlement: json['settlement'] == null
      ? null
      : TenancySettlementRef.fromJson(
          json['settlement'] as Map<String, dynamic>,
        ),
  version: (json['version'] as num?)?.toInt() ?? 1,
  actions:
      (json['actions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

const _$TenancyStatusEnumMap = {
  TenancyStatus.invited: 'INVITED',
  TenancyStatus.pendingMoveIn: 'PENDING_MOVE_IN',
  TenancyStatus.active: 'ACTIVE',
  TenancyStatus.notice: 'NOTICE',
  TenancyStatus.ended: 'ENDED',
  TenancyStatus.cancelled: 'CANCELLED',
  TenancyStatus.unknown: 'UNKNOWN',
};

TenancyApplication _$TenancyApplicationFromJson(
  Map<String, dynamic> json,
) => TenancyApplication(
  id: json['id'] as String,
  status:
      $enumDecodeNullable(
        _$ApplicationStatusEnumMap,
        json['status'],
        unknownValue: ApplicationStatus.unknown,
      ) ??
      ApplicationStatus.unknown,
  hostel: TenancyHostelRef.fromJson(json['hostel'] as Map<String, dynamic>),
  roomType: TenancyRoomRef.fromJson(json['roomType'] as Map<String, dynamic>),
  applicant: TenancyPerson.fromJson(json['applicant'] as Map<String, dynamic>),
  moveInDate: json['moveInDate'] as String,
  tenureMonths: (json['tenureMonths'] as num?)?.toInt(),
  occupation: json['occupation'] as String?,
  message: json['message'] as String?,
  emergencyContact: EmergencyContact.fromJson(
    json['emergencyContact'] as Map<String, dynamic>,
  ),
  decisionNote: json['decisionNote'] as String?,
  tenancyId: json['tenancyId'] as String?,
  actions:
      (json['actions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

const _$ApplicationStatusEnumMap = {
  ApplicationStatus.requested: 'REQUESTED',
  ApplicationStatus.approved: 'APPROVED',
  ApplicationStatus.rejected: 'REJECTED',
  ApplicationStatus.withdrawn: 'WITHDRAWN',
  ApplicationStatus.expired: 'EXPIRED',
  ApplicationStatus.unknown: 'UNKNOWN',
};

TermsRoom _$TermsRoomFromJson(Map<String, dynamic> json) => TermsRoom(
  roomTypeId: json['roomTypeId'] as String,
  name: json['name'] as String,
  kind:
      $enumDecodeNullable(
        _$RoomKindEnumMap,
        json['kind'],
        unknownValue: RoomKind.unknown,
      ) ??
      RoomKind.dorm,
  gender:
      $enumDecodeNullable(
        _$RoomGenderEnumMap,
        json['gender'],
        unknownValue: RoomGender.unknown,
      ) ??
      RoomGender.mixed,
  rentPaise: (json['rentPaise'] as num).toInt(),
  freeUnits: (json['freeUnits'] as num?)?.toInt() ?? 0,
);

const _$RoomGenderEnumMap = {
  RoomGender.mixed: 'MIXED',
  RoomGender.male: 'MALE',
  RoomGender.female: 'FEMALE',
  RoomGender.unknown: 'UNKNOWN',
};

TenancyTerms _$TenancyTermsFromJson(Map<String, dynamic> json) => TenancyTerms(
  depositMonths: (json['depositMonths'] as num?)?.toInt() ?? 2,
  noticeDays: (json['noticeDays'] as num?)?.toInt() ?? 30,
  rentDueDay: (json['rentDueDay'] as num?)?.toInt() ?? 1,
  rentGraceDays: (json['rentGraceDays'] as num?)?.toInt() ?? 5,
  rooms:
      (json['rooms'] as List<dynamic>?)
          ?.map((e) => TermsRoom.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

FreeUnit _$FreeUnitFromJson(Map<String, dynamic> json) => FreeUnit(
  id: json['id'] as String,
  label: json['label'] as String,
  floor: (json['floor'] as num?)?.toInt(),
);

OwnerRoom _$OwnerRoomFromJson(Map<String, dynamic> json) => OwnerRoom(
  id: json['id'] as String,
  name: json['name'] as String,
  basePricePaise: (json['basePricePaise'] as num?)?.toInt() ?? 0,
);

SettlementLine _$SettlementLineFromJson(Map<String, dynamic> json) =>
    SettlementLine(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'OTHER',
      description: json['description'] as String,
      amountPaise: (json['amountPaise'] as num).toInt(),
      invoiceId: json['invoiceId'] as String?,
    );

SettlementProof _$SettlementProofFromJson(Map<String, dynamic> json) =>
    SettlementProof(id: json['id'] as String, url: json['url'] as String);

OpenInvoiceRef _$OpenInvoiceRefFromJson(Map<String, dynamic> json) =>
    OpenInvoiceRef(
      id: json['id'] as String,
      number: json['number'] as String,
      balancePaise: (json['balancePaise'] as num).toInt(),
    );

SettlementPayout _$SettlementPayoutFromJson(Map<String, dynamic> json) =>
    SettlementPayout(
      online: json['online'] as bool? ?? false,
      method: json['method'] as String?,
      reference: json['reference'] as String?,
    );

DepositSettlement _$DepositSettlementFromJson(Map<String, dynamic> json) =>
    DepositSettlement(
      id: json['id'] as String,
      tenancyId: json['tenancyId'] as String,
      status:
          $enumDecodeNullable(
            _$SettlementStatusEnumMap,
            json['status'],
            unknownValue: SettlementStatus.unknown,
          ) ??
          SettlementStatus.unknown,
      depositPaise: (json['depositPaise'] as num).toInt(),
      deductionsPaise: (json['deductionsPaise'] as num?)?.toInt() ?? 0,
      refundPaise: (json['refundPaise'] as num).toInt(),
      note: json['note'] as String?,
      disputeNote: json['disputeNote'] as String?,
      respondBy: json['respondBy'] == null
          ? null
          : DateTime.parse(json['respondBy'] as String),
      autoAgreed: json['autoAgreed'] as bool? ?? false,
      payout: json['payout'] == null
          ? const SettlementPayout()
          : SettlementPayout.fromJson(json['payout'] as Map<String, dynamic>),
      deductions:
          (json['deductions'] as List<dynamic>?)
              ?.map((e) => SettlementLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      proofs:
          (json['proofs'] as List<dynamic>?)
              ?.map((e) => SettlementProof.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      openInvoices:
          (json['openInvoices'] as List<dynamic>?)
              ?.map((e) => OpenInvoiceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

const _$SettlementStatusEnumMap = {
  SettlementStatus.draft: 'DRAFT',
  SettlementStatus.proposed: 'PROPOSED',
  SettlementStatus.disputed: 'DISPUTED',
  SettlementStatus.agreed: 'AGREED',
  SettlementStatus.completed: 'COMPLETED',
  SettlementStatus.unknown: 'UNKNOWN',
};
