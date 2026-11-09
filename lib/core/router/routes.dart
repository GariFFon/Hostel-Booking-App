import '../format/format.dart';

/// Every path in one place, so call sites never build URLs by hand.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Tabs
  static const explore = '/';
  static const saved = '/saved';
  static const trips = '/trips';
  static const account = '/account';

  // Pushed above the tabs
  static const checkout = '/checkout';
  static const notifications = '/notifications';
  static const profile = '/account/profile';
  static const password = '/account/password';
  static const notificationSettings = '/account/notification-settings';
  static const myReviews = '/account/reviews';

  // Host mode
  static const host = '/host';
  static const hostBookings = '/host/bookings';
  static const hostListings = '/host/listings';
  static const hostReviews = '/host/reviews';

  static String hostel(String slug, {DateTime? checkIn, DateTime? checkOut, int? guests}) {
    final q = <String, String>{
      if (checkIn != null && checkOut != null) 'checkIn': toApiDate(checkIn),
      if (checkIn != null && checkOut != null) 'checkOut': toApiDate(checkOut),
      if (guests != null && guests > 1) 'guests': '$guests',
    };
    return Uri(path: '/hostel/$slug', queryParameters: q.isEmpty ? null : q).toString();
  }

  static String hostelReviews(String slug) => '/hostel/$slug/reviews';

  static String booking(String id, {bool pay = false}) => pay ? '/trips/$id?pay=1' : '/trips/$id';

  static String hostBooking(String id) => '/host/bookings/$id';

  /// Only same-app paths are acceptable redirect targets (no scheme, no `//host`).
  static String? safeNext(String? next) {
    if (next == null || next.isEmpty) return null;
    if (!next.startsWith('/') || next.startsWith('//') || next.contains('://')) return null;
    return next;
  }

  /// Pages that need a signed-in user. Tabs themselves are public and show a sign-in prompt instead.
  static bool needsSignIn(String location) =>
      location == checkout ||
      location == notifications ||
      location.startsWith('/trips/') ||
      location.startsWith('/account/') ||
      location == host || // not `startsWith('/host')`: that would also catch the public `/hostel/:slug` pages
      location.startsWith('$host/');
}
