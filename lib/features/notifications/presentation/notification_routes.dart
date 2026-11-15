import '../../../core/router/routes.dart';
import '../domain/notification_models.dart';

/// Host-facing notifications open the host view of the same booking.
String? notificationRoute(NotificationItem n) {
  final booking = n.bookingId;
  switch (n.type) {
    case NotificationType.bookingApprovalRequested:
      return booking == null ? Routes.host : Routes.hostBooking(booking);
    case NotificationType.reviewReceived:
      return Routes.hostReviews;
    case NotificationType.hostelApproved:
    case NotificationType.hostelRejected:
      return Routes.hostListings;
    case NotificationType.reviewReplied:
      return Routes.myReviews;
    case NotificationType.tenancyRequested:
      return Routes.hostTenants;
    case NotificationType.tenancyApproved ||
        NotificationType.tenancyRejected ||
        NotificationType.tenancyInvited ||
        NotificationType.tenancyStarted ||
        NotificationType.tenancyNotice ||
        NotificationType.tenancyEnded:
      return n.forOwner ? Routes.hostTenants : Routes.stay;
    case NotificationType.rentInvoiceIssued || NotificationType.rentDueSoon || NotificationType.rentOverdue || NotificationType.rentPaid:
      return n.forOwner ? Routes.hostRent : Routes.stay;
    case NotificationType.depositSettled:
      return n.forOwner ? Routes.hostTenants : Routes.stay;
    case NotificationType.complaintCreated ||
        NotificationType.complaintAssigned ||
        NotificationType.complaintUpdated ||
        NotificationType.complaintResolved:
      // Each person opens their own view of the complaint: the owner's inbox, the maintenance person's jobs, or the tenant's list.
      final id = n.data?['complaintId'] as String?;
      if (n.data?['audience'] == 'STAFF') return id == null ? Routes.staffJobs : '${Routes.staffJobs}/jobs/$id';
      if (n.forOwner) return id == null ? Routes.hostComplaints : '${Routes.hostComplaints}/$id';
      return id == null ? Routes.myComplaints : '${Routes.myComplaints}/$id';
    case NotificationType.staffInvited:
      return n.forOwner ? Routes.hostStaff : Routes.staffJobs;
    default:
      return booking == null ? null : Routes.booking(booking);
  }
}
