import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

/// Everything user-visible that depends on locale: money (INR, lakh grouping), calendar dates, plurals.
/// Stay dates are calendar dates (no time zone): never build them from UTC instants.

final NumberFormat _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final NumberFormat _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final NumberFormat _count = NumberFormat.decimalPattern('en_IN');

/// Integer paise -> "₹1,23,456" (or "₹1,250.50" when there are paise). Null -> an em dash.
String money(int? paise) {
  if (paise == null) return '—';
  final rupees = paise / 100;
  return paise % 100 == 0 ? _inr0.format(rupees) : _inr2.format(rupees);
}

/// "−₹200" for discounts and deductions.
String moneyOff(int paise) => '−${money(paise.abs())}';

/// Whole rupees without the symbol, for inputs.
String rupeesInt(int paise) => (paise ~/ 100).toString();

String count(int n) => _count.format(n);

/// "1 night", "2 nights", "1,284 members". Plurals are never hard-coded at call sites.
String plural(int n, String one, [String? many]) => '${count(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// A rating reads "New" until there is at least one review.
String ratingLabel(double avg, int reviews) => reviews <= 0 ? 'New' : avg.toStringAsFixed(1);

/// Parses `YYYY-MM-DD` as a calendar date at local midnight.
DateTime parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String toApiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

int nightsBetween(DateTime a, DateTime b) => dateOnly(b).difference(dateOnly(a)).inDays;

String fmtDay(DateTime d) => DateFormat('EEE, d MMM').format(d);
String fmtShort(DateTime d) => DateFormat('d MMM').format(d);
String fmtLong(DateTime d) => DateFormat('d MMM yyyy').format(d);
String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

/// "12–15 Mar" in one month, "28 Feb – 2 Mar" across months; the year is added when it is not the current one.
String fmtRange(DateTime a, DateTime b) {
  final now = DateTime.now().year;
  final withYear = !(a.year == now && b.year == now);
  if (a.year == b.year && a.month == b.month) {
    final s = '${a.day}–${b.day} ${DateFormat('MMM').format(b)}';
    return withYear ? '$s ${b.year}' : s;
  }
  return withYear ? '${fmtLong(a)} – ${fmtLong(b)}' : '${fmtShort(a)} – ${fmtShort(b)}';
}

/// "14:00" -> "2:00 PM". Anything unexpected is returned unchanged.
String fmtClock(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return hhmm;
  final h = int.parse(m.group(1)!);
  final min = m.group(2)!;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$min ${h < 12 ? 'AM' : 'PM'}';
}

String fmtDateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d.toLocal());

/// "just now", "5 min ago", "3 h ago", "Yesterday", else the date.
String relativeTime(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(when);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return fmtLong(when.toLocal());
}

/// `mm:ss` (or `h:mm:ss`) for countdowns.
String fmtCountdown(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// `PENDING_PAYMENT` / `pendingPayment` -> "Pending payment". Unknown enum values stay readable, never an error.
String humanize(String raw) {
  final spaced = raw.replaceAll('_', ' ').replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ').toLowerCase().trim();
  if (spaced.isEmpty) return raw;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// First-and-last-word initials from grapheme clusters, "?" for nothing usable, so emoji-first names do not break.
String initials(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  String first(String w) => w.characters.first.toUpperCase();
  if (words.length == 1) return first(words.first);
  return first(words.first) + first(words.last);
}
