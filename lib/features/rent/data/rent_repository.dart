import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../domain/rent_models.dart';

/// Rent: the tenant's invoices and online payment, and the owner's view of what is billed and collected.
class RentRepository {
  RentRepository(this._api);

  final ApiClient _api;

  // ── tenant ──
  Future<Paged<RentInvoice>> myInvoices({String? cursor}) =>
      _api.getPage('/me/rent-invoices', RentInvoice.fromJson, query: {'cursor': cursor, 'limit': 24});

  /// Starts (or resumes) an online payment of the invoice's whole balance.
  Future<RentOrder> startPayment(String invoiceId) => _api.postOne('/me/rent-invoices/$invoiceId/payments', RentOrder.fromJson);

  /// Starts (or resumes) an online payment of a stay's security deposit. It is completed through the same order endpoints as rent.
  Future<RentOrder> startDepositPayment(String tenancyId) => _api.postOne('/me/tenancies/$tenancyId/deposit/payments', RentOrder.fromJson);

  Future<RentOrder> demoCheckout(String orderId, {required String instrument, required String method}) =>
      _api.postOne('/me/rent-orders/$orderId/demo-checkout', RentOrder.fromJson, body: {'instrument': instrument, 'method': method});

  Future<RentOrder> order(String orderId) => _api.getOne('/me/rent-orders/$orderId', RentOrder.fromJson);

  /// A five-minute link to the PDF receipt of one of my payments.
  Future<String> receiptLink(String paymentId, {bool host = false}) async {
    final e = await _api.post('/${host ? 'owner' : 'me'}/rent-payments/$paymentId/receipt-link');
    return asMap(e.data)['url'] as String;
  }

  // ── owner ──
  Future<Paged<RentInvoice>> hostInvoices({String? status, bool overdue = false, String? cursor}) => _api.getPage(
    '/owner/rent-invoices',
    RentInvoice.fromJson,
    query: {'status': status, 'overdue': overdue ? 'true' : null, 'cursor': cursor, 'limit': 20},
  );

  Future<RentInvoice> hostInvoice(String id) => _api.getOne('/owner/rent-invoices/$id', RentInvoice.fromJson);

  Future<RentRoll> roll({String? month}) => _api.getOne('/owner/rent-roll', RentRoll.fromJson, query: {'month': month});

  /// A five-minute link to a rent invoice as a PDF.
  Future<String> invoicePdfLink(String invoiceId, {bool host = false}) async {
    final e = await _api.post('/${host ? 'owner' : 'me'}/rent-invoices/$invoiceId/pdf-link');
    return asMap(e.data)['url'] as String;
  }

  /// Pays part or all of an online payment back to the tenant.
  Future<RentInvoice> refund(String paymentId, {required int amountPaise, required String reason}) =>
      _api.postOne('/owner/rent-payments/$paymentId/refund', RentInvoice.fromJson, body: {'amountPaise': amountPaise, 'reason': reason.trim()});

  /// Records rent received outside the app (cash, UPI, bank).
  Future<RentInvoice> recordPayment(String id, {required int amountPaise, required String method, String? reference, String? receivedOn}) =>
      _api.postOne(
        '/owner/rent-invoices/$id/payments',
        RentInvoice.fromJson,
        body: {
          'amountPaise': amountPaise,
          'method': method,
          if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim(),
          'receivedOn': ?receivedOn,
        },
      );
}
