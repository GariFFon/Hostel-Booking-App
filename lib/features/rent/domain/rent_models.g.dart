// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rent_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvoiceLine _$InvoiceLineFromJson(Map<String, dynamic> json) => InvoiceLine(
  id: json['id'] as String,
  type: json['type'] as String,
  description: json['description'] as String,
  amountPaise: (json['amountPaise'] as num).toInt(),
);

RentPaymentItem _$RentPaymentItemFromJson(Map<String, dynamic> json) =>
    RentPaymentItem(
      id: json['id'] as String,
      receiptNo: json['receiptNo'] as String,
      amountPaise: (json['amountPaise'] as num).toInt(),
      method: json['method'] as String? ?? 'CASH',
      reference: json['reference'] as String?,
      receivedOn: json['receivedOn'] as String,
      reversed: json['reversed'] as bool? ?? false,
      reverseReason: json['reverseReason'] as String?,
      canReverse: json['canReverse'] as bool? ?? false,
      refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
      refundablePaise: (json['refundablePaise'] as num?)?.toInt() ?? 0,
      canRefund: json['canRefund'] as bool? ?? false,
      refunds:
          (json['refunds'] as List<dynamic>?)
              ?.map((e) => RentRefundItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

RentRefundItem _$RentRefundItemFromJson(Map<String, dynamic> json) =>
    RentRefundItem(
      id: json['id'] as String,
      amountPaise: (json['amountPaise'] as num).toInt(),
      status: json['status'] as String? ?? 'PENDING',
      reason: json['reason'] as String? ?? '',
    );

InvoiceOverdue _$InvoiceOverdueFromJson(Map<String, dynamic> json) =>
    InvoiceOverdue(
      isOverdue: json['isOverdue'] as bool? ?? false,
      days: (json['days'] as num?)?.toInt() ?? 0,
    );

InvoicePartyRef _$InvoicePartyRefFromJson(Map<String, dynamic> json) =>
    InvoicePartyRef(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String? ?? '',
    );

InvoiceHostelRef _$InvoiceHostelRefFromJson(Map<String, dynamic> json) =>
    InvoiceHostelRef(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
    );

InvoiceTenancyRef _$InvoiceTenancyRefFromJson(Map<String, dynamic> json) =>
    InvoiceTenancyRef(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      unitLabel: json['unitLabel'] as String? ?? '',
    );

OpenOrder _$OpenOrderFromJson(Map<String, dynamic> json) => OpenOrder(
  id: json['id'] as String,
  status: json['status'] as String? ?? 'CREATED',
  amountPaise: (json['amountPaise'] as num).toInt(),
);

RentInvoice _$RentInvoiceFromJson(Map<String, dynamic> json) => RentInvoice(
  id: json['id'] as String,
  number: json['number'] as String,
  status:
      $enumDecodeNullable(
        _$InvoiceStatusEnumMap,
        json['status'],
        unknownValue: InvoiceStatus.unknown,
      ) ??
      InvoiceStatus.unknown,
  hostel: InvoiceHostelRef.fromJson(json['hostel'] as Map<String, dynamic>),
  tenancy: InvoiceTenancyRef.fromJson(json['tenancy'] as Map<String, dynamic>),
  tenant: InvoicePartyRef.fromJson(json['tenant'] as Map<String, dynamic>),
  periodStart: json['periodStart'] as String,
  periodEnd: json['periodEnd'] as String,
  dueDate: json['dueDate'] as String,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtotalPaise: (json['subtotalPaise'] as num?)?.toInt() ?? 0,
  taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
  gstRateBps: (json['gstRateBps'] as num?)?.toInt() ?? 0,
  totalPaise: (json['totalPaise'] as num).toInt(),
  paidPaise: (json['paidPaise'] as num?)?.toInt() ?? 0,
  balancePaise: (json['balancePaise'] as num).toInt(),
  overdue: json['overdue'] == null
      ? const InvoiceOverdue()
      : InvoiceOverdue.fromJson(json['overdue'] as Map<String, dynamic>),
  payments:
      (json['payments'] as List<dynamic>?)
          ?.map((e) => RentPaymentItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  openOrder: json['openOrder'] == null
      ? null
      : OpenOrder.fromJson(json['openOrder'] as Map<String, dynamic>),
  voidReason: json['voidReason'] as String?,
  version: (json['version'] as num?)?.toInt() ?? 1,
  actions:
      (json['actions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

const _$InvoiceStatusEnumMap = {
  InvoiceStatus.due: 'DUE',
  InvoiceStatus.partiallyPaid: 'PARTIALLY_PAID',
  InvoiceStatus.paid: 'PAID',
  InvoiceStatus.voided: 'VOID',
  InvoiceStatus.unknown: 'UNKNOWN',
};

OrderAttempt _$OrderAttemptFromJson(Map<String, dynamic> json) => OrderAttempt(
  id: json['id'] as String,
  status: json['status'] as String? ?? 'INITIATED',
  instrument: json['instrument'] as String? ?? '',
);

OrderCheckout _$OrderCheckoutFromJson(Map<String, dynamic> json) =>
    OrderCheckout(
      type: json['type'] as String? ?? 'demo',
      instruments:
          (json['instruments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

RentOrder _$RentOrderFromJson(Map<String, dynamic> json) => RentOrder(
  id: json['id'] as String,
  invoiceId: json['invoiceId'] as String?,
  tenancyId: json['tenancyId'] as String?,
  kind: json['kind'] as String? ?? 'RENT',
  amountPaise: (json['amountPaise'] as num).toInt(),
  status:
      $enumDecodeNullable(
        _$RentOrderStatusEnumMap,
        json['status'],
        unknownValue: RentOrderStatus.unknown,
      ) ??
      RentOrderStatus.unknown,
  failureReason: json['failureReason'] as String?,
  attempts:
      (json['attempts'] as List<dynamic>?)
          ?.map((e) => OrderAttempt.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  checkout: json['checkout'] == null
      ? null
      : OrderCheckout.fromJson(json['checkout'] as Map<String, dynamic>),
);

const _$RentOrderStatusEnumMap = {
  RentOrderStatus.created: 'CREATED',
  RentOrderStatus.pending: 'PENDING',
  RentOrderStatus.captured: 'CAPTURED',
  RentOrderStatus.failed: 'FAILED',
  RentOrderStatus.partiallyRefunded: 'PARTIALLY_REFUNDED',
  RentOrderStatus.refunded: 'REFUNDED',
  RentOrderStatus.unknown: 'UNKNOWN',
};

RollTotals _$RollTotalsFromJson(Map<String, dynamic> json) => RollTotals(
  invoices: (json['invoices'] as num?)?.toInt() ?? 0,
  invoicedPaise: (json['invoicedPaise'] as num?)?.toInt() ?? 0,
  collectedPaise: (json['collectedPaise'] as num?)?.toInt() ?? 0,
  collectedOnlinePaise: (json['collectedOnlinePaise'] as num?)?.toInt() ?? 0,
  collectedOfflinePaise: (json['collectedOfflinePaise'] as num?)?.toInt() ?? 0,
  outstandingPaise: (json['outstandingPaise'] as num?)?.toInt() ?? 0,
  overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
  overduePaise: (json['overduePaise'] as num?)?.toInt() ?? 0,
);

RentRoll _$RentRollFromJson(Map<String, dynamic> json) => RentRoll(
  month: json['month'] as String,
  activeTenants: (json['activeTenants'] as num?)?.toInt() ?? 0,
  totals: json['totals'] == null
      ? const RollTotals()
      : RollTotals.fromJson(json['totals'] as Map<String, dynamic>),
);
