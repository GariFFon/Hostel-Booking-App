import 'package:flutter/material.dart';

import '../../../core/format/format.dart';

/// Calendar for choosing a stay (check-in to check-out, at least one night). Returns null when dismissed.
Future<({DateTime checkIn, DateTime checkOut})?> pickStayDates(BuildContext context, {DateTime? checkIn, DateTime? checkOut}) async {
  final now = today();
  final range = await showDateRangePicker(
    context: context,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
    initialDateRange: checkIn != null && checkOut != null && !checkIn.isBefore(now) ? DateTimeRange(start: checkIn, end: checkOut) : null,
    helpText: 'Select your stay',
    saveText: 'Done',
  );
  if (range == null) return null;
  final start = dateOnly(range.start);
  final end = range.end.isAfter(range.start) ? dateOnly(range.end) : start.add(const Duration(days: 1));
  return (checkIn: start, checkOut: end);
}
