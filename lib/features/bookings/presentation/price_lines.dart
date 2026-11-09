import '../../../core/format/format.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../domain/booking_models.dart';
import '../domain/quote_models.dart';

/// `500` bps -> "5%", `1250` -> "12.5%".
String fmtBps(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}%';
  final v = bps / 100;
  return '${v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}%';
}

/// "₹899 × 3 nights" (per bed or room); several units say so. Uses the average so weekend/seasonal rates stay honest.
String _unitDetail({required int lineTotalPaise, required int units, required int nights}) {
  final per = (lineTotalPaise / (units < 1 ? 1 : units) / (nights < 1 ? 1 : nights)).round();
  final each = units > 1 ? ' each' : '';
  return '${money(per)}$each × ${plural(nights, 'night')}';
}

List<PriceLine> quotePriceLines(Quote q) => [
  for (final i in q.items)
    PriceLine(
      '${i.name} × ${i.units}',
      i.lineSubtotalPaise,
      detail: _unitDetail(lineTotalPaise: i.lineSubtotalPaise, units: i.units, nights: q.nights),
    ),
  if (q.discountPaise > 0) PriceLine(q.couponApplied ? 'Discount (${q.coupon!.code})' : 'Discount', q.discountPaise, discount: true),
  PriceLine('GST (${fmtBps(q.effectiveGstBps)})', q.taxPaise),
  if (q.serviceFeePaise > 0) PriceLine('Service fee', q.serviceFeePaise),
];

List<PriceLine> bookingPriceLines(Booking b) {
  final p = b.pricing;
  return [
    for (final i in b.items)
      PriceLine(
        '${i.name} × ${i.units}',
        i.lineTotalPaise,
        detail: _unitDetail(lineTotalPaise: i.lineTotalPaise, units: i.units, nights: b.nights),
      ),
    if (p.discountPaise > 0) PriceLine(p.couponCode != null ? 'Discount (${p.couponCode})' : 'Discount', p.discountPaise, discount: true),
    PriceLine('GST (${fmtBps(p.effectiveGstBps)})', p.taxPaise),
    if (p.serviceFeePaise > 0) PriceLine('Service fee', p.serviceFeePaise),
  ];
}
