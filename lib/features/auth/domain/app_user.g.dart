// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: json['fullName'] as String?,
  phone: json['phone'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  roles:
      (json['roles'] as List<dynamic>?)
          ?.map(
            (e) => $enumDecode(
              _$UserRoleEnumMap,
              e,
              unknownValue: UserRole.unknown,
            ),
          )
          .toList() ??
      [],
  emailVerified: json['emailVerified'] as bool? ?? false,
  hasPassword: json['hasPassword'] as bool? ?? true,
  googleLinked: json['googleLinked'] as bool? ?? false,
  kycStatus: $enumDecodeNullable(
    _$KycStatusEnumMap,
    json['kycStatus'],
    unknownValue: KycStatus.unknown,
  ),
);

const _$UserRoleEnumMap = {
  UserRole.guest: 'GUEST',
  UserRole.owner: 'OWNER',
  UserRole.admin: 'ADMIN',
  UserRole.unknown: 'UNKNOWN',
};

const _$KycStatusEnumMap = {
  KycStatus.notSubmitted: 'NOT_SUBMITTED',
  KycStatus.pending: 'PENDING',
  KycStatus.approved: 'APPROVED',
  KycStatus.rejected: 'REJECTED',
  KycStatus.unknown: 'UNKNOWN',
};

AuthResult _$AuthResultFromJson(Map<String, dynamic> json) => AuthResult(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
);
