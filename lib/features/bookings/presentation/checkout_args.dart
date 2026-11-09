import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hostels/domain/hostel_models.dart';
import '../data/booking_repository.dart';

/// Everything the checkout screen needs, handed over by the hostel page. (`go_router` `extra`: not restored after a process
/// restart, in which case the checkout screen just goes back to the hostel.)
class CheckoutArgs {
  const CheckoutArgs({required this.hostel, required this.checkIn, required this.checkOut, required this.guests, required this.items});

  final HostelDetail hostel;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final List<RoomSelection> items;
}

/// The checkout the guest is heading into. go_router's `extra` is lost when the router detours through sign-in (a signed-out
/// visitor taps Reserve, signs in, and is sent to `/checkout` without it), so the arguments are also kept here until the
/// booking is made. Held in memory only: after a process restart the checkout screen says it expired.
final pendingCheckoutProvider = NotifierProvider<PendingCheckout, CheckoutArgs?>(PendingCheckout.new);

class PendingCheckout extends Notifier<CheckoutArgs?> {
  @override
  CheckoutArgs? build() => null;

  void set(CheckoutArgs? args) => state = args;
}
