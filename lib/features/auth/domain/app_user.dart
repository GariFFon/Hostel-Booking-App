import 'package:json_annotation/json_annotation.dart';

part 'app_user.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum UserRole { guest, owner, admin, unknown }

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum KycStatus { notSubmitted, pending, approved, rejected, unknown }

@JsonSerializable(createToJson: false)
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.roles = const [],
    this.emailVerified = false,
    this.hasPassword = true,
    this.googleLinked = false,
    this.kycStatus,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  @JsonKey(defaultValue: <UserRole>[], unknownEnumValue: UserRole.unknown)
  final List<UserRole> roles;
  final bool emailVerified;
  final bool hasPassword;
  final bool googleLinked;
  @JsonKey(unknownEnumValue: KycStatus.unknown)
  final KycStatus? kycStatus;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  bool get isOwner => roles.contains(UserRole.owner);
  bool get isAdmin => roles.contains(UserRole.admin);

  /// What to call this person: first name, else the part of the email before the @.
  String get displayName {
    final n = fullName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return email.split('@').first;
  }

  String get firstName => displayName.split(RegExp(r'\s+')).first;
}

/// Response of login / register / refresh / password change.
@JsonSerializable(createToJson: false)
class AuthResult {
  const AuthResult({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => _$AuthResultFromJson(json);
}
