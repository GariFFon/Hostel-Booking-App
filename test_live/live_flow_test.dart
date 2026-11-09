// Live contract test: drives the app's real repositories against a running local backend (`make dev-be` + `make worker`,
// seeded DB). Not part of `flutter test` (it lives outside `test/`). Run with:
//   flutter test test_live/live_flow_test.dart
// It cancels every booking it creates, so inventory is left as it was found.
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/format/format.dart';
import 'package:hostel_booking_app/core/network/api_client.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/core/network/token_store.dart';
import 'package:hostel_booking_app/core/util/ids.dart';
import 'package:hostel_booking_app/features/auth/data/auth_repository.dart';
import 'package:hostel_booking_app/features/bookings/data/booking_repository.dart';
import 'package:hostel_booking_app/features/bookings/domain/booking_models.dart';
import 'package:hostel_booking_app/features/host/data/host_repository.dart';
import 'package:hostel_booking_app/features/hostels/data/hostel_repository.dart';
import 'package:hostel_booking_app/features/hostels/data/search_params.dart';
import 'package:hostel_booking_app/features/hostels/domain/enums.dart';
import 'package:hostel_booking_app/features/notifications/data/notification_repository.dart';
import 'package:hostel_booking_app/features/reviews/data/review_repository.dart';
import 'package:hostel_booking_app/features/wishlist/data/wishlist_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const _base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:4000/api/v1');
const _password = 'Password@123';

class _MemoryTokens implements TokenStore {
  TokenPair? _t;
  @override
  Future<TokenPair?> read() async => _t;
  @override
  Future<void> write(TokenPair tokens) async => _t = tokens;
  @override
  Future<void> clear() async => _t = null;
}

class _Session {
  _Session._(this.api, this.auth);
  final ApiClient api;
  final AuthRepository auth;
  late final bookings = BookingRepository(api);
  late final hostels = HostelRepository(api);
  late final host = HostRepository(api);

  static Future<_Session> signIn(String email) async {
    final tokens = _MemoryTokens();
    final api = ApiClient(baseUrl: _base, tokens: tokens);
    final auth = AuthRepository(api, tokens);
    await auth.login(email: email, password: _password);
    return _Session._(api, auth);
  }
}

Future<Booking> _waitFor(BookingRepository repo, String id, bool Function(Booking) done, {int seconds = 40}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  Booking b;
  do {
    b = await repo.detail(id);
    if (done(b)) return b;
    await Future<void>.delayed(const Duration(seconds: 1));
  } while (DateTime.now().isBefore(end));
  fail('Timed out waiting; last status ${b.status}');
}

void main() {
  late _Session guest;
  late _Session owner1;
  late _Session owner3;
  final cleanup = <Future<void> Function()>[];

  setUpAll(() async {
    await initializeDateFormatting('en_IN');
    Intl.defaultLocale = 'en_IN';
    guest = await _Session.signIn('guest1@hostel.dev');
    owner1 = await _Session.signIn('owner1@hostel.dev');
    owner3 = await _Session.signIn('owner3@hostel.dev');
  });

  tearDownAll(() async {
    for (final c in cleanup.reversed) {
      try {
        await c();
      } catch (_) {}
    }
  });

  test('session: /me parses and the guest is not a host', () async {
    final me = await guest.auth.me();
    expect(me.email, 'guest1@hostel.dev');
    expect(me.isOwner, isFalse);
    expect((await owner1.auth.me()).isOwner, isTrue);
  });

  test('instant booking: quote, book (idempotent), pay by demo gateway, confirm, host sees it, guest cancels with refund', () async {
    final found = await guest.hostels.search(const SearchParams(q: 'Palolem'));
    final card = found.items.firstWhere((h) => h.name.contains('Palolem'));
    final detail = await guest.hostels.detail(card.slug);
    expect(detail.bookingMode, BookingMode.instant);

    final checkIn = dateOnly(DateTime.now().add(const Duration(days: 75)));
    final checkOut = checkIn.add(const Duration(days: 2));
    final avail = await guest.hostels.availability(card.slug, checkIn: checkIn, checkOut: checkOut, guests: 1);
    final room = avail.rooms.firstWhere((r) => r.eligible && r.availableUnits > 0);
    final items = [RoomSelection(room.roomTypeId, 1)];

    final quote = await guest.bookings.quote(hostelId: detail.id, checkIn: checkIn, checkOut: checkOut, guests: 1, items: items);
    expect(quote.nights, 2);
    expect(quote.totalPaise, greaterThan(0));
    expect(quote.totalPaise, quote.subtotalPaise - quote.discountPaise + quote.taxPaise + quote.serviceFeePaise);

    // A stale price must be refused with details the checkout screen can show.
    try {
      await guest.bookings.create(
        idempotencyKey: newIdempotencyKey(),
        hostelId: detail.id,
        checkIn: checkIn,
        checkOut: checkOut,
        items: items,
        guests: const [GuestInput(fullName: 'Guest One')],
        contactPhone: '+919876543210',
        expectedTotalPaise: quote.totalPaise + 100,
      );
      fail('expected PRICE_CHANGED');
    } on ApiException catch (e) {
      expect(e.code, 'PRICE_CHANGED');
      expect((e.details as Map)['totalPaise'], quote.totalPaise);
      expect((e.details as Map)['expectedTotalPaise'], quote.totalPaise + 100);
    }

    // Field errors arrive keyed by the paths the form uses.
    try {
      await guest.bookings.create(
        idempotencyKey: newIdempotencyKey(),
        hostelId: detail.id,
        checkIn: checkIn,
        checkOut: checkOut,
        items: items,
        guests: const [GuestInput(fullName: 'X')],
        contactPhone: 'abc',
        expectedTotalPaise: quote.totalPaise,
      );
      fail('expected VALIDATION_FAILED');
    } on ApiException catch (e) {
      expect(e.isValidation, isTrue);
      expect(e.fieldErrors.keys, containsAll(['contactPhone', 'guests.0.fullName']));
    }

    final key = newIdempotencyKey();
    Future<Booking> book() => guest.bookings.create(
          idempotencyKey: key,
          hostelId: detail.id,
          checkIn: checkIn,
          checkOut: checkOut,
          items: items,
          guests: const [GuestInput(fullName: 'Guest One', gender: 'FEMALE', age: 27)],
          contactPhone: '+919876543210',
          specialRequests: 'Late arrival',
          expectedTotalPaise: quote.totalPaise,
        );
    final b = await book();
    cleanup.add(() async {
      final now = await guest.bookings.detail(b.id);
      if (now.can(BookingAction.cancel)) await guest.bookings.cancel(b.id, reason: 'live test cleanup');
    });
    final again = await book();
    expect(again.id, b.id, reason: 'same idempotency key replays the same booking');

    expect(b.status, BookingStatus.pendingPayment);
    expect(b.can(BookingAction.pay), isTrue);
    expect(b.can(BookingAction.cancel), isTrue);
    expect(b.holdExpiresAt, isNotNull);
    expect(b.holdExpiresAt!.isAfter(DateTime.now()), isTrue);
    expect(b.pricing.totalPaise, quote.totalPaise);
    expect(b.guests.single.fullName, 'Guest One');
    expect(b.hostel.slug, card.slug);
    expect(b.nights, 2);

    final upcoming = await guest.bookings.list(when: 'upcoming');
    expect(upcoming.items.any((s) => s.id == b.id), isTrue);

    // Pay.
    final order = await guest.bookings.startPayment(b.id, idempotencyKey: newIdempotencyKey());
    expect(order.amountPaise, quote.totalPaise);
    expect(order.checkout?.instruments, containsAll(['DEMO_SUCCESS', 'DEMO_FAIL']));
    await guest.bookings.demoCheckout(order.id, instrument: 'DEMO_SUCCESS', method: 'UPI');
    final confirmed = await _waitFor(guest.bookings, b.id, (x) => x.status == BookingStatus.confirmed);
    expect(confirmed.payment?.status.toUpperCase(), 'CAPTURED');
    expect(confirmed.hostel.phone, isNotNull, reason: 'the property phone is revealed once confirmed');
    expect(confirmed.can(BookingAction.pay), isFalse);
    expect(confirmed.can(BookingAction.cancel), isTrue);
    expect(confirmed.timeline.map((e) => e.status), containsAllInOrder([BookingStatus.pendingPayment, BookingStatus.confirmed]));
    expect(confirmed.cancellation, isNotNull);

    // Host side.
    final hostView = await owner1.host.booking(b.id);
    expect(hostView.viewer, ViewerRole.owner);
    expect(hostView.ownerShare, isNotNull);
    expect(hostView.ownerShare!.ownerNetPaise, greaterThan(0));
    expect(hostView.guest?.name, isNotNull);
    expect(hostView.can(BookingAction.pay), isFalse);
    final hostList = await owner1.host.bookings(when: 'upcoming');
    expect(hostList.items.any((s) => s.id == b.id), isTrue);
    final earnings = await owner1.host.earnings();
    expect(earnings.currency, 'INR');

    // Cancel with a refund preview first.
    final preview = await guest.bookings.cancellationPreview(b.id);
    expect(preview.refundPaise + preview.retainedPaise, quote.totalPaise);
    final cancelled = await guest.bookings.cancel(b.id, reason: 'live test');
    expect(cancelled.status, BookingStatus.cancelledByGuest);
    expect(cancelled.refund, isNotNull);
    expect(cancelled.refund!.amountPaise, preview.refundPaise);
    expect(cancelled.actions, isEmpty);
    final past = await guest.bookings.list(when: 'past');
    expect(past.items.any((s) => s.id == b.id), isTrue);
  });

  test('failed payment: the failure reason reaches the screen, the booking stays payable, a fresh order can be started', () async {
    final found = await guest.hostels.search(const SearchParams(q: 'Palolem'));
    final card = found.items.firstWhere((h) => h.name.contains('Palolem'));
    final detail = await guest.hostels.detail(card.slug);
    final checkIn = dateOnly(DateTime.now().add(const Duration(days: 80)));
    final checkOut = checkIn.add(const Duration(days: 1));
    final avail = await guest.hostels.availability(card.slug, checkIn: checkIn, checkOut: checkOut, guests: 1);
    final room = avail.rooms.firstWhere((r) => r.eligible && r.availableUnits > 0);
    final items = [RoomSelection(room.roomTypeId, 1)];
    final quote = await guest.bookings.quote(hostelId: detail.id, checkIn: checkIn, checkOut: checkOut, guests: 1, items: items);
    final b = await guest.bookings.create(
      idempotencyKey: newIdempotencyKey(),
      hostelId: detail.id,
      checkIn: checkIn,
      checkOut: checkOut,
      items: items,
      guests: const [GuestInput(fullName: 'Guest One')],
      contactPhone: '+919876543210',
      expectedTotalPaise: quote.totalPaise,
    );
    cleanup.add(() async {
      final now = await guest.bookings.detail(b.id);
      if (now.can(BookingAction.cancel)) await guest.bookings.cancel(b.id);
    });

    final order = await guest.bookings.startPayment(b.id, idempotencyKey: newIdempotencyKey());
    await guest.bookings.demoCheckout(order.id, instrument: 'DEMO_FAIL', method: 'CARD');
    final failed = await _waitFor(guest.bookings, b.id, (x) => x.payment?.status.toUpperCase() == 'FAILED');
    expect(failed.payment!.failureReason, isNotNull);
    expect(failed.status, BookingStatus.pendingPayment);
    expect(failed.can(BookingAction.pay), isTrue);

    final retry = await guest.bookings.startPayment(b.id, idempotencyKey: newIdempotencyKey());
    expect(retry.id, isNot(order.id), reason: 'a failed order is final; the retry gets a fresh one');
    expect(retry.status.isFinal, isFalse);
  });

  test('request-to-book: waits for the host, host accepts, guest can then pay; a gendered stay needs gender', () async {
    final found = await guest.hostels.search(const SearchParams(q: 'Koregaon'));
    final card = found.items.firstWhere((h) => h.bookingMode == BookingMode.approval);
    final detail = await guest.hostels.detail(card.slug);
    expect(detail.genderPolicy, isNot(GenderPolicy.mixed));

    final checkIn = dateOnly(DateTime.now().add(const Duration(days: 90)));
    final nights = detail.roomTypes.map((r) => r.minStayNights).reduce((a, b) => a > b ? a : b).clamp(1, 30);
    final checkOut = checkIn.add(Duration(days: nights));
    final avail = await guest.hostels.availability(card.slug, checkIn: checkIn, checkOut: checkOut, guests: 1);
    final room = avail.rooms.firstWhere((r) => r.eligible && r.availableUnits > 0);
    final items = [RoomSelection(room.roomTypeId, 1)];
    final quote = await guest.bookings.quote(hostelId: detail.id, checkIn: checkIn, checkOut: checkOut, guests: 1, items: items);
    final b = await guest.bookings.create(
      idempotencyKey: newIdempotencyKey(),
      hostelId: detail.id,
      checkIn: checkIn,
      checkOut: checkOut,
      items: items,
      guests: const [GuestInput(fullName: 'Guest One', gender: 'MALE')],
      contactPhone: '+919876543210',
      expectedTotalPaise: quote.totalPaise,
    );
    cleanup.add(() async {
      final now = await guest.bookings.detail(b.id);
      if (now.can(BookingAction.cancel)) await guest.bookings.cancel(b.id);
    });
    expect(b.status, BookingStatus.pendingApproval);
    expect(b.can(BookingAction.pay), isFalse, reason: 'nothing to pay until the host accepts');
    expect(b.approvalDeadline, isNotNull);

    final hostView = await owner3.host.booking(b.id);
    expect(hostView.can(BookingAction.approve), isTrue);
    expect(hostView.can(BookingAction.reject), isTrue);
    final requests = await owner3.host.bookings(status: 'PENDING_APPROVAL');
    expect(requests.items.any((s) => s.id == b.id), isTrue);

    final approved = await owner3.host.approve(b.id);
    expect(approved.status, BookingStatus.pendingPayment);
    final guestView = await guest.bookings.detail(b.id);
    expect(guestView.can(BookingAction.pay), isTrue);

    final cancelled = await guest.bookings.cancel(b.id);
    expect(cancelled.status, BookingStatus.cancelledByGuest);
  });

  test('wishlist, notifications and reviews round-trip through the real API', () async {
    final wish = WishlistRepository(guest.api);
    final found = await guest.hostels.search(const SearchParams(q: 'Palolem'));
    final palolem = found.items.firstWhere((h) => h.name.contains('Palolem'));
    final id = palolem.id;
    final before = await wish.ids();
    if (before.contains(id)) await wish.remove(id);
    await wish.add(id);
    expect((await wish.ids()).contains(id), isTrue);
    final listed = await wish.list();
    expect(listed.items.any((e) => e.hostel.id == id), isTrue);
    await wish.remove(id);
    expect((await wish.ids()).contains(id), isFalse);
    if (before.contains(id)) await wish.add(id); // leave it as found

    final notes = NotificationRepository(guest.api);
    final inbox = await notes.list();
    expect(inbox.items, isNotEmpty, reason: 'earlier steps produced booking notifications');
    final unread = await notes.unreadCount();
    expect(unread, greaterThanOrEqualTo(0));
    final prefs = await notes.prefs();
    expect(prefs.inAppBookings, isA<bool>());

    final reviews = ReviewRepository(guest.api);
    final mine = await reviews.mine();
    expect(mine.items, isA<List<Object?>>());
    final summary = await reviews.summary(palolem.slug);
    expect(summary.reviewCount, greaterThanOrEqualTo(0));
  });

  test('errors: not found, forbidden and unauthenticated are mapped to their codes', () async {
    try {
      await guest.bookings.detail('00000000-0000-4000-8000-000000000000');
      fail('expected NOT_FOUND');
    } on ApiException catch (e) {
      expect(e.isNotFound, isTrue);
    }
    try {
      await guest.host.earnings();
      fail('expected FORBIDDEN');
    } on ApiException catch (e) {
      expect(e.isForbidden, isTrue);
    }
    final anon = ApiClient(baseUrl: _base, tokens: _MemoryTokens());
    try {
      await BookingRepository(anon).list();
      fail('expected UNAUTHENTICATED');
    } on ApiException catch (e) {
      expect(e.isUnauthenticated, isTrue);
    }
  });
}
