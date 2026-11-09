// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentAttempt _$PaymentAttemptFromJson(Map<String, dynamic> json) => PaymentAttempt(
  id: json['id'] as String,
  status: $enumDecodeNullable(_$AttemptStatusEnumMap, json['status'], unknownValue: AttemptStatus.unknown) ?? AttemptStatus.unknown,
  instrument: json['instrument'] as String? ?? '',
  method: json['method'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

const _$AttemptStatusEnumMap = {
  AttemptStatus.initiated: 'INITIATED',
  AttemptStatus.pending: 'PENDING',
  AttemptStatus.succeeded: 'SUCCEEDED',
  AttemptStatus.failed: 'FAILED',
  AttemptStatus.unknown: 'UNKNOWN',
};

PaymentCheckout _$PaymentCheckoutFromJson(Map<String, dynamic> json) => PaymentCheckout(
  type: json['type'] as String? ?? 'demo',
  instruments: (json['instruments'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
);

PaymentOrder _$PaymentOrderFromJson(Map<String, dynamic> json) => PaymentOrder(
  id: json['id'] as String,
  bookingId: json['bookingId'] as String,
  provider: json['provider'] as String? ?? 'demo',
  providerOrderId: json['providerOrderId'] as String? ?? '',
  amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
  refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
  currency: json['currency'] as String? ?? 'INR',
  status: $enumDecodeNullable(_$PaymentStatusEnumMap, json['status'], unknownValue: PaymentStatus.unknown) ?? PaymentStatus.unknown,
  method: json['method'] as String?,
  failureCode: json['failureCode'] as String?,
  failureReason: json['failureReason'] as String?,
  capturedAt: json['capturedAt'] as String?,
  expiresAt: json['expiresAt'] as String?,
  attempts: (json['attempts'] as List<dynamic>?)?.map((e) => PaymentAttempt.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  checkout: json['checkout'] == null ? null : PaymentCheckout.fromJson(json['checkout'] as Map<String, dynamic>),
);

const _$PaymentStatusEnumMap = {
  PaymentStatus.created: 'CREATED',
  PaymentStatus.pending: 'PENDING',
  PaymentStatus.captured: 'CAPTURED',
  PaymentStatus.failed: 'FAILED',
  PaymentStatus.partiallyRefunded: 'PARTIALLY_REFUNDED',
  PaymentStatus.refunded: 'REFUNDED',
  PaymentStatus.unknown: 'UNKNOWN',
};

CancellationPreview _$CancellationPreviewFromJson(Map<String, dynamic> json) => CancellationPreview(
  refundPercent: (json['refundPercent'] as num?)?.toInt() ?? 0,
  refundPaise: (json['refundPaise'] as num?)?.toInt() ?? 0,
  retainedPaise: (json['retainedPaise'] as num?)?.toInt() ?? 0,
  currency: json['currency'] as String? ?? 'INR',
);
