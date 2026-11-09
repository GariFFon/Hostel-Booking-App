import 'package:json_annotation/json_annotation.dart';

part 'payment_models.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum PaymentStatus {
  created,
  pending,
  captured,
  failed,
  partiallyRefunded,
  refunded,
  unknown;

  bool get isPaid => this == captured || this == partiallyRefunded || this == refunded;
  bool get isFinal => isPaid || this == failed;
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum AttemptStatus { initiated, pending, succeeded, failed, unknown }

@JsonSerializable(createToJson: false)
class PaymentAttempt {
  const PaymentAttempt({required this.id, this.status = AttemptStatus.unknown, this.instrument = '', this.method, required this.createdAt});
  final String id;
  @JsonKey(unknownEnumValue: AttemptStatus.unknown)
  final AttemptStatus status;
  final String instrument;
  final String? method;
  final DateTime createdAt;
  factory PaymentAttempt.fromJson(Map<String, dynamic> json) => _$PaymentAttemptFromJson(json);
}

@JsonSerializable(createToJson: false)
class PaymentCheckout {
  const PaymentCheckout({this.type = 'demo', this.instruments = const []});
  final String type;
  @JsonKey(defaultValue: <String>[])
  final List<String> instruments;
  factory PaymentCheckout.fromJson(Map<String, dynamic> json) => _$PaymentCheckoutFromJson(json);
}

@JsonSerializable(createToJson: false)
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.bookingId,
    this.provider = 'demo',
    this.providerOrderId = '',
    this.amountPaise = 0,
    this.refundedPaise = 0,
    this.currency = 'INR',
    this.status = PaymentStatus.unknown,
    this.method,
    this.failureCode,
    this.failureReason,
    this.capturedAt,
    this.expiresAt,
    this.attempts = const [],
    this.checkout,
  });

  final String id;
  final String bookingId;
  final String provider;
  final String providerOrderId;
  final int amountPaise;
  final int refundedPaise;
  final String currency;
  @JsonKey(unknownEnumValue: PaymentStatus.unknown)
  final PaymentStatus status;
  final String? method;
  final String? failureCode;
  final String? failureReason;
  final String? capturedAt;
  final String? expiresAt;
  @JsonKey(defaultValue: <PaymentAttempt>[])
  final List<PaymentAttempt> attempts;
  final PaymentCheckout? checkout;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => _$PaymentOrderFromJson(json);

  bool get hasPendingAttempt => attempts.any((a) => a.status == AttemptStatus.pending || a.status == AttemptStatus.initiated);
}

@JsonSerializable(createToJson: false)
class CancellationPreview {
  const CancellationPreview({this.refundPercent = 0, this.refundPaise = 0, this.retainedPaise = 0, this.currency = 'INR'});
  final int refundPercent;
  final int refundPaise;
  final int retainedPaise;
  final String currency;
  factory CancellationPreview.fromJson(Map<String, dynamic> json) => _$CancellationPreviewFromJson(json);
}
