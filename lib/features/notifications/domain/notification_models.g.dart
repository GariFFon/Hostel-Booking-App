// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) => NotificationItem(
  id: json['id'] as String,
  type: $enumDecodeNullable(_$NotificationTypeEnumMap, json['type'], unknownValue: NotificationType.unknown) ?? NotificationType.unknown,
  title: json['title'] as String,
  body: json['body'] as String? ?? '',
  data: json['data'] as Map<String, dynamic>?,
  read: json['read'] as bool? ?? false,
  readAt: json['readAt'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

const _$NotificationTypeEnumMap = {
  NotificationType.bookingCreated: 'BOOKING_CREATED',
  NotificationType.bookingConfirmed: 'BOOKING_CONFIRMED',
  NotificationType.bookingApprovalRequested: 'BOOKING_APPROVAL_REQUESTED',
  NotificationType.bookingApproved: 'BOOKING_APPROVED',
  NotificationType.bookingRejected: 'BOOKING_REJECTED',
  NotificationType.bookingExpired: 'BOOKING_EXPIRED',
  NotificationType.bookingCancelled: 'BOOKING_CANCELLED',
  NotificationType.bookingReminder: 'BOOKING_REMINDER',
  NotificationType.paymentSucceeded: 'PAYMENT_SUCCEEDED',
  NotificationType.paymentFailed: 'PAYMENT_FAILED',
  NotificationType.refundProcessed: 'REFUND_PROCESSED',
  NotificationType.reviewRequested: 'REVIEW_REQUESTED',
  NotificationType.reviewReceived: 'REVIEW_RECEIVED',
  NotificationType.reviewReplied: 'REVIEW_REPLIED',
  NotificationType.hostelApproved: 'HOSTEL_APPROVED',
  NotificationType.hostelRejected: 'HOSTEL_REJECTED',
  NotificationType.kycApproved: 'KYC_APPROVED',
  NotificationType.kycRejected: 'KYC_REJECTED',
  NotificationType.tenancyRequested: 'TENANCY_REQUESTED',
  NotificationType.tenancyApproved: 'TENANCY_APPROVED',
  NotificationType.tenancyRejected: 'TENANCY_REJECTED',
  NotificationType.tenancyInvited: 'TENANCY_INVITED',
  NotificationType.tenancyStarted: 'TENANCY_STARTED',
  NotificationType.tenancyNotice: 'TENANCY_NOTICE',
  NotificationType.tenancyEnded: 'TENANCY_ENDED',
  NotificationType.rentInvoiceIssued: 'RENT_INVOICE_ISSUED',
  NotificationType.rentDueSoon: 'RENT_DUE_SOON',
  NotificationType.rentOverdue: 'RENT_OVERDUE',
  NotificationType.rentPaid: 'RENT_PAID',
  NotificationType.depositSettled: 'DEPOSIT_SETTLED',
  NotificationType.complaintCreated: 'COMPLAINT_CREATED',
  NotificationType.complaintAssigned: 'COMPLAINT_ASSIGNED',
  NotificationType.complaintUpdated: 'COMPLAINT_UPDATED',
  NotificationType.complaintResolved: 'COMPLAINT_RESOLVED',
  NotificationType.staffInvited: 'STAFF_INVITED',
  NotificationType.system: 'SYSTEM',
  NotificationType.unknown: 'UNKNOWN',
};

NotificationPrefs _$NotificationPrefsFromJson(Map<String, dynamic> json) => NotificationPrefs(
  emailBookings: json['emailBookings'] as bool? ?? true,
  emailMarketing: json['emailMarketing'] as bool? ?? false,
  inAppBookings: json['inAppBookings'] as bool? ?? true,
  inAppReviews: json['inAppReviews'] as bool? ?? true,
  inAppRent: json['inAppRent'] as bool? ?? true,
  emailRent: json['emailRent'] as bool? ?? true,
  inAppComplaints: json['inAppComplaints'] as bool? ?? true,
);
