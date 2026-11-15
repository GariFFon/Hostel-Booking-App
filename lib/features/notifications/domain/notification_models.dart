import 'package:json_annotation/json_annotation.dart';

part 'notification_models.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum NotificationType {
  bookingCreated,
  bookingConfirmed,
  bookingApprovalRequested,
  bookingApproved,
  bookingRejected,
  bookingExpired,
  bookingCancelled,
  bookingReminder,
  paymentSucceeded,
  paymentFailed,
  refundProcessed,
  reviewRequested,
  reviewReceived,
  reviewReplied,
  hostelApproved,
  hostelRejected,
  kycApproved,
  kycRejected,
  tenancyRequested,
  tenancyApproved,
  tenancyRejected,
  tenancyInvited,
  tenancyStarted,
  tenancyNotice,
  tenancyEnded,
  rentInvoiceIssued,
  rentDueSoon,
  rentOverdue,
  rentPaid,
  depositSettled,
  complaintCreated,
  complaintAssigned,
  complaintUpdated,
  complaintResolved,
  staffInvited,
  system,
  unknown;

  bool get isBooking => name.startsWith('booking') || name.startsWith('payment') || name.startsWith('refund');
  bool get isReview => name.startsWith('review');
  bool get isTenancy => name.startsWith('tenancy') || name.startsWith('rent') || name.startsWith('deposit');
}

@JsonSerializable(createToJson: false)
class NotificationItem {
  const NotificationItem({
    required this.id,
    this.type = NotificationType.unknown,
    required this.title,
    this.body = '',
    this.data,
    this.read = false,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  @JsonKey(unknownEnumValue: NotificationType.unknown)
  final NotificationType type;
  final String title;
  final String body;

  /// Deep-link ids such as `bookingId` or `hostelId`.
  final Map<String, dynamic>? data;
  final bool read;
  final String? readAt;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => _$NotificationItemFromJson(json);

  NotificationItem asRead() => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    read: true,
    readAt: readAt ?? DateTime.now().toIso8601String(),
    createdAt: createdAt,
  );

  String? get bookingId => data?['bookingId'] as String?;

  /// Who a tenancy notification is for: `OWNER` or `TENANT`.
  bool get forOwner => data?['audience'] == 'OWNER';
  String? get hostelId => data?['hostelId'] as String?;
}

@JsonSerializable(createToJson: false)
class NotificationPrefs {
  const NotificationPrefs({
    this.emailBookings = true,
    this.emailMarketing = false,
    this.inAppBookings = true,
    this.inAppReviews = true,
    this.inAppRent = true,
    this.emailRent = true,
    this.inAppComplaints = true,
  });
  final bool emailBookings;
  final bool emailMarketing;
  final bool inAppBookings;
  final bool inAppReviews;

  /// Stay, rent and deposit updates.
  final bool inAppRent;

  /// Rent bills and reminders by email (receipts and corrections are always sent).
  final bool emailRent;
  final bool inAppComplaints;
  factory NotificationPrefs.fromJson(Map<String, dynamic> json) => _$NotificationPrefsFromJson(json);

  NotificationPrefs copyWith({
    bool? emailBookings,
    bool? emailMarketing,
    bool? inAppBookings,
    bool? inAppReviews,
    bool? inAppRent,
    bool? emailRent,
    bool? inAppComplaints,
  }) => NotificationPrefs(
    emailBookings: emailBookings ?? this.emailBookings,
    emailMarketing: emailMarketing ?? this.emailMarketing,
    inAppBookings: inAppBookings ?? this.inAppBookings,
    inAppReviews: inAppReviews ?? this.inAppReviews,
    inAppRent: inAppRent ?? this.inAppRent,
    emailRent: emailRent ?? this.emailRent,
    inAppComplaints: inAppComplaints ?? this.inAppComplaints,
  );
}
