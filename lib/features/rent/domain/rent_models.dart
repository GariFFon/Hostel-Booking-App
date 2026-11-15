import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/format.dart';

part 'rent_models.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum InvoiceStatus {
  due('Due'),
  partiallyPaid('Part paid'),
  paid('Paid'),
  @JsonValue('VOID')
  voided('Cancelled'),
  unknown('Invoice');

  const InvoiceStatus(this.label);
  final String label;

  /// Still owes money.
  bool get isOpen => this == due || this == partiallyPaid;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum RentOrderStatus {
  created,
  pending,
  captured,
  failed,
  partiallyRefunded,
  refunded,
  unknown;

  bool get isOpen => this == created || this == pending;
}

@JsonSerializable(createToJson: false)
class InvoiceLine {
  const InvoiceLine({required this.id, required this.type, required this.description, required this.amountPaise});
  final String id;
  final String type;
  final String description;
  final int amountPaise;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => _$InvoiceLineFromJson(json);
}

@JsonSerializable(createToJson: false)
class RentPaymentItem {
  const RentPaymentItem({
    required this.id,
    required this.receiptNo,
    required this.amountPaise,
    this.method = 'CASH',
    this.reference,
    required this.receivedOn,
    this.reversed = false,
    this.reverseReason,
    this.canReverse = false,
    this.refundedPaise = 0,
    this.refundablePaise = 0,
    this.canRefund = false,
    this.refunds = const [],
  });
  final String id;
  final String receiptNo;
  final int amountPaise;

  /// CASH, UPI, BANK or ONLINE.
  final String method;
  final String? reference;
  final String receivedOn;
  final bool reversed;
  final String? reverseReason;
  final bool canReverse;

  /// Online payments only: money already returned, what can still be returned, and whether this caller may refund it.
  final int refundedPaise;
  final int refundablePaise;
  final bool canRefund;
  final List<RentRefundItem> refunds;

  String get methodLabel => method == 'ONLINE' ? 'Online' : humanize(method);
  DateTime get received => parseDate(receivedOn);

  factory RentPaymentItem.fromJson(Map<String, dynamic> json) => _$RentPaymentItemFromJson(json);
}

/// Money returned to the tenant for an online payment.
@JsonSerializable(createToJson: false)
class RentRefundItem {
  const RentRefundItem({required this.id, required this.amountPaise, this.status = 'PENDING', this.reason = ''});
  final String id;
  final int amountPaise;

  /// PENDING (on its way), PROCESSED or FAILED.
  final String status;
  final String reason;

  String get label => switch (status) {
    'PROCESSED' => 'Refunded',
    'FAILED' => 'Refund failed',
    _ => 'Refund on its way',
  };

  factory RentRefundItem.fromJson(Map<String, dynamic> json) => _$RentRefundItemFromJson(json);
}

@JsonSerializable(createToJson: false)
class InvoiceOverdue {
  const InvoiceOverdue({this.isOverdue = false, this.days = 0});
  final bool isOverdue;
  final int days;

  factory InvoiceOverdue.fromJson(Map<String, dynamic> json) => _$InvoiceOverdueFromJson(json);
}

@JsonSerializable(createToJson: false)
class InvoicePartyRef {
  const InvoicePartyRef({this.id = '', this.name, this.email = ''});
  final String id;
  final String? name;
  final String email;

  String get display => (name != null && name!.trim().isNotEmpty) ? name! : email;

  factory InvoicePartyRef.fromJson(Map<String, dynamic> json) => _$InvoicePartyRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class InvoiceHostelRef {
  const InvoiceHostelRef({required this.id, required this.name, this.city = ''});
  final String id;
  final String name;
  final String city;

  factory InvoiceHostelRef.fromJson(Map<String, dynamic> json) => _$InvoiceHostelRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class InvoiceTenancyRef {
  const InvoiceTenancyRef({required this.id, this.code = '', this.unitLabel = ''});
  final String id;
  final String code;
  final String unitLabel;

  factory InvoiceTenancyRef.fromJson(Map<String, dynamic> json) => _$InvoiceTenancyRefFromJson(json);
}

@JsonSerializable(createToJson: false)
class OpenOrder {
  const OpenOrder({required this.id, this.status = 'CREATED', required this.amountPaise});
  final String id;
  final String status;
  final int amountPaise;

  factory OpenOrder.fromJson(Map<String, dynamic> json) => _$OpenOrderFromJson(json);
}

@JsonSerializable(createToJson: false)
class RentInvoice {
  const RentInvoice({
    required this.id,
    required this.number,
    this.status = InvoiceStatus.unknown,
    required this.hostel,
    required this.tenancy,
    required this.tenant,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    this.lines = const [],
    this.subtotalPaise = 0,
    this.taxPaise = 0,
    this.gstRateBps = 0,
    required this.totalPaise,
    this.paidPaise = 0,
    required this.balancePaise,
    this.overdue = const InvoiceOverdue(),
    this.payments = const [],
    this.openOrder,
    this.voidReason,
    this.version = 1,
    this.actions = const [],
  });

  final String id;
  final String number;
  @JsonKey(unknownEnumValue: InvoiceStatus.unknown)
  final InvoiceStatus status;
  final InvoiceHostelRef hostel;
  final InvoiceTenancyRef tenancy;
  final InvoicePartyRef tenant;
  final String periodStart;
  final String periodEnd;
  final String dueDate;
  final List<InvoiceLine> lines;
  final int subtotalPaise;
  final int taxPaise;
  final int gstRateBps;
  final int totalPaise;
  final int paidPaise;
  final int balancePaise;
  final InvoiceOverdue overdue;
  final List<RentPaymentItem> payments;
  final OpenOrder? openOrder;
  final String? voidReason;
  final int version;

  /// What the server lets the current viewer do: `pay` (tenant); `record_payment`, `add_line`, `void` (owner).
  final List<String> actions;

  DateTime get start => parseDate(periodStart);
  DateTime get end => parseDate(periodEnd);
  DateTime get due => parseDate(dueDate);
  bool can(String action) => actions.contains(action);

  factory RentInvoice.fromJson(Map<String, dynamic> json) => _$RentInvoiceFromJson(json);
}

@JsonSerializable(createToJson: false)
class OrderAttempt {
  const OrderAttempt({required this.id, this.status = 'INITIATED', this.instrument = ''});
  final String id;
  final String status;
  final String instrument;

  factory OrderAttempt.fromJson(Map<String, dynamic> json) => _$OrderAttemptFromJson(json);
}

@JsonSerializable(createToJson: false)
class OrderCheckout {
  const OrderCheckout({this.type = 'demo', this.instruments = const []});
  final String type;
  final List<String> instruments;

  factory OrderCheckout.fromJson(Map<String, dynamic> json) => _$OrderCheckoutFromJson(json);
}

/// An online attempt to pay an invoice's balance.
@JsonSerializable(createToJson: false)
class RentOrder {
  const RentOrder({
    required this.id,
    this.invoiceId,
    this.tenancyId,
    this.kind = 'RENT',
    required this.amountPaise,
    this.status = RentOrderStatus.unknown,
    this.failureReason,
    this.attempts = const [],
    this.checkout,
  });
  final String id;

  /// Set for a rent payment; null for a security deposit payment (then [tenancyId] is set and [kind] is DEPOSIT).
  final String? invoiceId;
  final String? tenancyId;
  final String kind;
  final int amountPaise;
  @JsonKey(unknownEnumValue: RentOrderStatus.unknown)
  final RentOrderStatus status;
  final String? failureReason;
  final List<OrderAttempt> attempts;
  final OrderCheckout? checkout;

  factory RentOrder.fromJson(Map<String, dynamic> json) => _$RentOrderFromJson(json);
}

@JsonSerializable(createToJson: false)
class RollTotals {
  const RollTotals({
    this.invoices = 0,
    this.invoicedPaise = 0,
    this.collectedPaise = 0,
    this.collectedOnlinePaise = 0,
    this.collectedOfflinePaise = 0,
    this.outstandingPaise = 0,
    this.overdueCount = 0,
    this.overduePaise = 0,
  });
  final int invoices;
  final int invoicedPaise;
  final int collectedPaise;
  final int collectedOnlinePaise;
  final int collectedOfflinePaise;
  final int outstandingPaise;
  final int overdueCount;
  final int overduePaise;

  factory RollTotals.fromJson(Map<String, dynamic> json) => _$RollTotalsFromJson(json);
}

/// What is billed, collected and still owed for a month.
@JsonSerializable(createToJson: false)
class RentRoll {
  const RentRoll({required this.month, this.activeTenants = 0, this.totals = const RollTotals()});
  final String month;
  final int activeTenants;
  final RollTotals totals;

  factory RentRoll.fromJson(Map<String, dynamic> json) => _$RentRollFromJson(json);
}
