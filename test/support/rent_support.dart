import 'package:hostel_booking_app/core/network/api_exception.dart';
import 'package:hostel_booking_app/core/network/envelope.dart';
import 'package:hostel_booking_app/features/rent/data/rent_repository.dart';
import 'package:hostel_booking_app/features/rent/domain/rent_models.dart';

Map<String, dynamic> invoiceJson({
  String id = 'i1',
  String status = 'DUE',
  int total = 750000,
  int paid = 0,
  List<String> actions = const ['pay'],
  bool overdue = false,
  int overdueDays = 0,
  List<Map<String, dynamic>> payments = const [],
  List<Map<String, dynamic>> extraLines = const [],
  Map<String, dynamic>? openOrder,
  int tax = 0,
}) => {
  'id': id,
  'number': 'INV-2702-ABC234',
  'status': status,
  'hostel': {'id': 'h1', 'name': 'Koregaon Park Students PG', 'city': 'Pune'},
  'tenancy': {'id': 't1', 'code': 'TN-ABC234', 'unitLabel': 'B-1'},
  'tenant': {'id': 's1', 'name': 'Asha Rao', 'email': 'asha@example.com', 'phone': null},
  'periodStart': '2027-02-01',
  'periodEnd': '2027-02-28',
  'dueDate': '2027-02-05',
  'lines': [
    {'id': 'l1', 'type': 'RENT', 'description': 'Rent for February 2027', 'amountPaise': total - tax},
    ...extraLines,
  ],
  'subtotalPaise': total - tax,
  'taxPaise': tax,
  'gstRateBps': tax > 0 ? 500 : 0,
  'totalPaise': total,
  'paidPaise': paid,
  'balancePaise': total - paid,
  'overdue': {'isOverdue': overdue, 'days': overdueDays},
  'payments': payments,
  'openOrder': openOrder,
  'voidReason': null,
  'version': 1,
  'actions': actions,
};

Map<String, dynamic> paymentJson({
  int amount = 250000,
  String method = 'CASH',
  bool reversed = false,
  int refunded = 0,
  bool canRefund = false,
  List<Map<String, dynamic>> refunds = const [],
}) => {
  'id': 'p1',
  'receiptNo': 'RCPT-2702-XYZ789',
  'amountPaise': amount,
  'method': method,
  'reference': null,
  'receivedOn': '2027-02-03',
  'reversed': reversed,
  'reverseReason': null,
  'canReverse': !reversed && method != 'ONLINE',
  'refundedPaise': refunded,
  'refundablePaise': canRefund ? amount - refunded : 0,
  'canRefund': canRefund,
  'refunds': refunds,
};

Map<String, dynamic> orderJson({String status = 'CREATED', int amount = 750000, String? failure}) => {
  'id': 'o1',
  'invoiceId': 'i1',
  'provider': 'demo',
  'amountPaise': amount,
  'currency': 'INR',
  'status': status,
  'failureReason': failure,
  'attempts': <Map<String, dynamic>>[],
  'checkout': status == 'CREATED' || status == 'PENDING'
      ? {
          'type': 'demo',
          'instruments': ['DEMO_SUCCESS', 'DEMO_PENDING', 'DEMO_FAIL', 'DEMO_TIMEOUT'],
        }
      : null,
};

Map<String, dynamic> rollJson({int overdueCount = 0}) => {
  'month': '2027-02',
  'activeTenants': 3,
  'totals': {
    'invoices': 3,
    'invoicedPaise': 2250000,
    'collectedPaise': 1000000,
    'collectedOnlinePaise': 750000,
    'collectedOfflinePaise': 250000,
    'outstandingPaise': 1250000,
    'overdueCount': overdueCount,
    'overduePaise': overdueCount * 750000,
  },
};

/// A scripted rent repository: set what a test needs, and read back what the UI sent.
class FakeRentRepository implements RentRepository {
  List<RentInvoice> mine = const [];
  List<RentInvoice> overdue = const [];
  List<RentInvoice> due = const [];
  List<RentInvoice> paid = const [];
  RentRoll rollData = RentRoll.fromJson(rollJson());

  /// What the next order polls return, in order (the last one repeats).
  List<RentOrder> pollResults = [RentOrder.fromJson(orderJson(status: 'CAPTURED'))];
  ApiException? startError;
  ApiException? recordError;

  final calls = <String>[];
  int startCalls = 0;
  String? lastInstrument;
  String? lastMethod;
  ({int amountPaise, String method, String? reference})? lastRecord;
  ({String paymentId, int amountPaise, String reason})? lastRefund;
  String receiptUrl = 'https://api.example.com/api/v1/receipts/abc.def';
  String? lastReceiptFor;
  bool? lastReceiptAsHost;
  int _poll = 0;

  Paged<T> _page<T>(List<T> items) => Paged<T>(items: items);

  @override
  Future<Paged<RentInvoice>> myInvoices({String? cursor}) async => _page(mine);

  @override
  Future<RentOrder> startPayment(String invoiceId) async {
    startCalls++;
    if (startError != null) throw startError!;
    return RentOrder.fromJson(orderJson());
  }

  @override
  Future<RentOrder> demoCheckout(String orderId, {required String instrument, required String method}) async {
    calls.add('checkout:$instrument');
    lastInstrument = instrument;
    lastMethod = method;
    return RentOrder.fromJson(orderJson(status: 'PENDING'));
  }

  @override
  Future<RentOrder> order(String orderId) async {
    calls.add('poll');
    final r = pollResults[_poll.clamp(0, pollResults.length - 1)];
    _poll++;
    return r;
  }

  @override
  Future<Paged<RentInvoice>> hostInvoices({String? status, bool overdue = false, String? cursor}) async =>
      _page(overdue ? this.overdue : (status == 'PAID' ? paid : due));

  @override
  Future<RentInvoice> hostInvoice(String id) async => [...overdue, ...due, ...paid].firstWhere((i) => i.id == id);

  @override
  Future<RentOrder> startDepositPayment(String tenancyId) async {
    calls.add('startDeposit:$tenancyId');
    startCalls++;
    return RentOrder.fromJson({...orderJson(amount: 1200000), 'invoiceId': null, 'tenancyId': tenancyId, 'kind': 'DEPOSIT'});
  }

  @override
  Future<String> receiptLink(String paymentId, {bool host = false}) async {
    calls.add('receipt');
    lastReceiptFor = paymentId;
    lastReceiptAsHost = host;
    return receiptUrl;
  }

  bool? lastInvoicePdfAsHost;
  String? lastInvoicePdfFor;
  String invoicePdfUrl = 'https://api.example.com/api/v1/receipts/inv.sig';

  @override
  Future<String> invoicePdfLink(String invoiceId, {bool host = false}) async {
    calls.add('invoicePdf');
    lastInvoicePdfFor = invoiceId;
    lastInvoicePdfAsHost = host;
    return invoicePdfUrl;
  }

  @override
  Future<RentInvoice> refund(String paymentId, {required int amountPaise, required String reason}) async {
    calls.add('refund');
    lastRefund = (paymentId: paymentId, amountPaise: amountPaise, reason: reason.trim());
    return [...overdue, ...due, ...paid, ...mine].first;
  }

  @override
  Future<RentRoll> roll({String? month}) async => rollData;

  @override
  Future<RentInvoice> recordPayment(String id, {required int amountPaise, required String method, String? reference, String? receivedOn}) async {
    calls.add('record');
    if (recordError != null) throw recordError!;
    lastRecord = (amountPaise: amountPaise, method: method, reference: reference);
    return hostInvoice(id);
  }
}
