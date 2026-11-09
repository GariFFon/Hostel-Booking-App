import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/my_reviews_screen.dart';
import '../../features/account/presentation/notification_settings_screen.dart';
import '../../features/account/presentation/profile_screens.dart';
import '../../features/bookings/presentation/trips_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/wishlist/presentation/saved_screen.dart';
import '../../features/auth/application/session.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/password_reset_screens.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/bookings/presentation/booking_detail_screen.dart';
import '../../features/bookings/presentation/checkout_args.dart';
import '../../features/bookings/presentation/checkout_screen.dart';
import '../../features/host/application/host_providers.dart';
import '../../features/host/presentation/host_home_screen.dart';
import '../../features/host/presentation/host_lists_screens.dart';
import '../../features/hostels/presentation/explore_screen.dart';
import '../../features/reviews/presentation/hostel_reviews_screen.dart';
import '../../features/hostels/presentation/hostel_screen.dart';
import '../format/format.dart';
import 'main_shell.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routing + guards. The session is the only thing that changes where you are allowed to be:
/// while it is unknown you see the splash, signed-out visitors are sent to sign in (and brought back), signed-in users skip sign-in.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.explore,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final here = state.uri.toString();

      if (!session.hasValue) {
        return loc == Routes.splash ? null : '${Routes.splash}?next=${Uri.encodeComponent(here)}';
      }
      final signedIn = session.value != null;
      if (loc == Routes.splash) return Routes.safeNext(state.uri.queryParameters['next']) ?? Routes.explore;
      if (!signedIn && Routes.needsSignIn(loc)) return '${Routes.login}?next=${Uri.encodeComponent(here)}';
      final authPages = {Routes.login, Routes.register, Routes.forgotPassword};
      if (signedIn && authPages.contains(loc)) return Routes.safeNext(state.uri.queryParameters['next']) ?? Routes.explore;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.login,
        builder: (_, s) => LoginScreen(next: Routes.safeNext(s.uri.queryParameters['next'])),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, s) => RegisterScreen(next: Routes.safeNext(s.uri.queryParameters['next'])),
      ),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, s) => ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/hostel/:slug',
        builder: (_, s) {
          final q = s.uri.queryParameters;
          DateTime? tryDate(String? v) => v == null ? null : (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? parseDate(v) : null);
          final ci = tryDate(q['checkIn']);
          final co = tryDate(q['checkOut']);
          final valid = ci != null && co != null && co.isAfter(ci);
          return HostelScreen(
            slug: s.pathParameters['slug']!,
            checkIn: valid ? ci : null,
            checkOut: valid ? co : null,
            guests: (int.tryParse(q['guests'] ?? '') ?? 1).clamp(1, 30),
          );
        },
      ),
      GoRoute(
        path: '/hostel/:slug/reviews',
        builder: (_, s) => HostelReviewsScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: Routes.checkout,
        builder: (_, s) => CheckoutScreen(args: s.extra is CheckoutArgs ? s.extra as CheckoutArgs : null),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (_, s) => BookingDetailScreen(id: s.pathParameters['id']!, autoPay: s.uri.queryParameters['pay'] == '1'),
      ),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: Routes.password, builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: Routes.notificationSettings, builder: (_, _) => const NotificationSettingsScreen()),
      GoRoute(path: Routes.myReviews, builder: (_, _) => const MyReviewsScreen()),
      GoRoute(path: Routes.host, builder: (_, _) => const HostHomeScreen()),
      GoRoute(
        path: Routes.hostBookings,
        builder: (_, s) => HostBookingsScreen(
          initial: HostBookingTab.values.firstWhere((t) => t.name == s.uri.queryParameters['tab'], orElse: () => HostBookingTab.upcoming),
        ),
      ),
      GoRoute(path: Routes.hostListings, builder: (_, _) => const HostListingsScreen()),
      GoRoute(path: Routes.hostReviews, builder: (_, _) => const HostReviewsScreen()),
      GoRoute(
        path: '/host/bookings/:id',
        builder: (_, s) => BookingDetailScreen(id: s.pathParameters['id']!, host: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.explore, builder: (_, _) => const ExploreScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.saved, builder: (_, _) => const SavedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.trips, builder: (_, _) => const TripsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
