import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/core/providers.dart';
import 'package:hostel_booking_app/core/theme/app_theme.dart';
import 'package:hostel_booking_app/features/auth/application/session.dart';
import 'package:hostel_booking_app/features/auth/domain/app_user.dart';
import 'package:hostel_booking_app/features/bookings/data/booking_repository.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/bookings/domain/payment_models.dart';
import 'package:hostel_booking_app/features/bookings/domain/quote_models.dart';
import 'package:hostel_booking_app/features/hostels/domain/hostel_models.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Call once per test file so date/number formatting matches the app (`en_IN`).
Future<void> initLocale() async {
  await initializeDateFormatting('en_IN');
  Intl.defaultLocale = 'en_IN';
}

const guestUser = AppUser(id: 'u1', email: 'asha@example.com', fullName: 'Asha Rao', phone: '+919876543210', emailVerified: true);

/// A session that is already resolved (no network, no secure storage).
class FakeSession extends SessionController {
  FakeSession(this.user);
  final AppUser? user;

  @override
  Future<AppUser?> build() async => user;
}

Map<String, dynamic> hostelJson({String genderPolicy = 'MIXED', String bookingMode = 'INSTANT', String roomGender = 'MIXED'}) => {
      'id': 'h1',
      'slug': 'palolem-beach-hostel',
      'name': 'Palolem Beach Hostel',
      'bookingMode': bookingMode,
      'genderPolicy': genderPolicy,
      'address': {'line1': '1 Beach Rd', 'city': 'Goa', 'state': 'Goa'},
      'location': {'latitude': 15.0, 'longitude': 74.0},
      'roomTypes': [
        {'id': 'r1', 'name': '6-bed dorm', 'kind': 'DORM', 'gender': roomGender, 'capacity': 6, 'fromPricePaise': 80000},
      ],
    };

HostelDetail hostel({String genderPolicy = 'MIXED', String bookingMode = 'INSTANT', String roomGender = 'MIXED'}) =>
    HostelDetail.fromJson(hostelJson(genderPolicy: genderPolicy, bookingMode: bookingMode, roomGender: roomGender));

Map<String, dynamic> quoteJson({int total = 252000, String? couponCode, bool couponValid = true}) => {
      'hostelId': 'h1',
      'hostelName': 'Palolem Beach Hostel',
      'checkIn': '2026-12-01',
      'checkOut': '2026-12-04',
      'nights': 3,
      'guests': 2,
      'items': [
        {'roomTypeId': 'r1', 'name': '6-bed dorm', 'kind': 'DORM', 'units': 2, 'nightly': <dynamic>[], 'lineSubtotalPaise': 240000},
      ],
      'subtotalPaise': 240000,
      'discountPaise': 0,
      'taxPaise': total - 240000,
      'serviceFeePaise': 0,
      'totalPaise': total,
      'effectiveGstBps': 500,
      if (couponCode != null)
        'coupon': {'code': couponCode, 'valid': couponValid, 'discountPaise': couponValid ? 10000 : 0, if (!couponValid) 'message': 'This coupon has expired.'},
      'cancellation': {'policy': 'FLEXIBLE', 'summary': 'Free cancellation until 2 days before check-in.', 'tiers': <dynamic>[]},
      'bookingMode': 'INSTANT',
    };

Map<String, dynamic> bookingJson({
  String status = 'PENDING_PAYMENT',
  List<String> actions = const ['pay', 'cancel'],
  String viewer = 'GUEST',
  String hostelName = 'Palolem Beach Hostel',
  Map<String, dynamic>? payment,
  String? holdExpiresAt,
  int total = 252000,
}) =>
    {
      'id': 'b1',
      'code': 'HB-ABC123',
      'status': status,
      'viewer': viewer,
      'checkIn': '2026-12-01',
      'checkOut': '2026-12-04',
      'nights': 3,
      'guestsCount': 2,
      'hostel': {
        'id': 'h1',
        'slug': 'palolem-beach-hostel',
        'name': hostelName,
        'city': 'Goa',
        'state': 'Goa',
        'addressLine1': '1 Beach Rd',
        'location': {'latitude': 15.0, 'longitude': 74.0},
      },
      'items': [
        {'roomTypeId': 'r1', 'name': '6-bed dorm', 'units': 2, 'lineTotalPaise': 240000, 'nightly': <dynamic>[]},
      ],
      'guests': [
        {'fullName': 'Asha Rao', 'isPrimary': true},
      ],
      'pricing': {'subtotalPaise': 240000, 'taxPaise': total - 240000, 'totalPaise': total, 'effectiveGstBps': 500},
      'bookingMode': 'INSTANT',
      'cancellationPolicy': 'FLEXIBLE',
      'holdExpiresAt': ?holdExpiresAt,
      'payment': ?payment,
      'actions': actions,
      'createdAt': '2026-11-10T10:00:00.000Z',
    };

Booking booking({
  String status = 'PENDING_PAYMENT',
  List<String> actions = const ['pay', 'cancel'],
  String viewer = 'GUEST',
  Map<String, dynamic>? payment,
  int total = 252000,
}) =>
    Booking.fromJson(bookingJson(status: status, actions: actions, viewer: viewer, payment: payment, total: total));

PaymentOrder paymentOrder({String status = 'CREATED'}) => PaymentOrder.fromJson({
      'id': 'p1',
      'bookingId': 'b1',
      'amountPaise': 252000,
      'status': status,
      'checkout': {
        'type': 'demo',
        'instruments': ['DEMO_SUCCESS', 'DEMO_PENDING', 'DEMO_FAIL', 'DEMO_TIMEOUT'],
      },
    });

/// Hand-rolled fake: every call is recorded, behaviour is set per test with closures.
class FakeBookingRepository implements BookingRepository {
  Future<Quote> Function()? onQuote;
  Future<Booking> Function(String idempotencyKey, int expectedTotalPaise, List<GuestInput> guests, String contactPhone)? onCreate;
  Future<Booking> Function()? onDetail;
  Future<PaymentOrder> Function()? onStartPayment;
  Future<PaymentOrder> Function(String instrument)? onDemoCheckout;

  final createKeys = <String>[];
  final createGuests = <List<GuestInput>>[];
  final createPhones = <String>[];
  final createExpected = <int>[];
  int startPaymentCalls = 0;
  int quoteCalls = 0;
  String? lastCouponCode;

  @override
  Future<Quote> quote({
    required String hostelId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required List<RoomSelection> items,
    String? couponCode,
  }) {
    quoteCalls++;
    lastCouponCode = couponCode;
    return onQuote!();
  }

  @override
  Future<Booking> create({
    required String idempotencyKey,
    required String hostelId,
    required DateTime checkIn,
    required DateTime checkOut,
    required List<RoomSelection> items,
    required List<GuestInput> guests,
    required String contactPhone,
    String? couponCode,
    String? specialRequests,
    required int expectedTotalPaise,
  }) {
    createKeys.add(idempotencyKey);
    createGuests.add(guests);
    createPhones.add(contactPhone);
    createExpected.add(expectedTotalPaise);
    return onCreate!(idempotencyKey, expectedTotalPaise, guests, contactPhone);
  }

  @override
  Future<Booking> detail(String id) => onDetail!();

  @override
  Future<PaymentOrder> startPayment(String bookingId, {required String idempotencyKey}) {
    startPaymentCalls++;
    return onStartPayment!();
  }

  @override
  Future<PaymentOrder> demoCheckout(String paymentId, {required String instrument, String method = 'UPI'}) => onDemoCheckout!(instrument);

  @override
  Future<Paged<BookingSummary>> list({String when = 'all', String? cursor, int limit = 20}) async => Paged.empty<BookingSummary>();

  @override
  Future<CancellationPreview> cancellationPreview(String id) async => const CancellationPreview();

  @override
  Future<Booking> cancel(String id, {String? reason}) => throw UnimplementedError();

  @override
  Future<PaymentOrder> payment(String paymentId) => throw UnimplementedError();
}

/// Pumps [screen] inside the real theme, a ProviderScope and a tiny router (so `context.push/pop` work).
/// `/trips/:id` and `/` are stubs that print where you landed.
Future<GoRouter> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/screen', builder: (_, _) => screen),
      GoRoute(path: '/trips/:id', builder: (_, s) => Scaffold(body: Text('detail ${s.pathParameters['id']} ${s.uri.query}'))),
    ],
  );
  addTearDown(router.dispose);

  // The real router only shows these screens once the session is known, so resolve it first.
  final container = ProviderContainer(overrides: overrides, retry: noAutomaticRetry);
  addTearDown(container.dispose);
  await container.read(sessionProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

List<Override> baseOverrides({AppUser? user = guestUser, FakeBookingRepository? repo}) => [
      sessionProvider.overrideWith(() => FakeSession(user)),
      if (repo != null) bookingRepositoryProvider.overrideWithValue(repo),
    ];
