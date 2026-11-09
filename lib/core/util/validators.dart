/// Client-side checks mirror the backend's limits so people hear about a mistake before a round trip.
/// The server stays the authority: its field errors are shown too.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final RegExp _inPhone = RegExp(r'^(\+91|91|0)?[6-9]\d{9}$');

  static String? required(String? v, String message) => (v == null || v.trim().isEmpty) ? message : null;

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email';
    if (s.length > 254 || !_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Choose a password';
    if (s.length < 8) return 'Use at least 8 characters';
    if (s.length > 128) return 'Use 128 characters or fewer';
    return null;
  }

  static String? fullName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your full name';
    if (s.length < 2) return 'Enter your full name';
    if (s.length > 100) return 'Use 100 characters or fewer';
    return null;
  }

  /// Indian mobile number: 10 digits starting 6-9, optionally with +91.
  static String? mobile(String? v, {bool optional = false}) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return optional ? null : 'Enter a mobile number';
    return _inPhone.hasMatch(s) ? null : 'Enter a 10-digit mobile number';
  }

  /// `98765 43210` / `09876543210` / `+91 98765-43210` -> `+919876543210`. Anything else is returned trimmed.
  static String normaliseMobile(String v) {
    final s = v.replaceAll(RegExp(r'[\s-]'), '');
    final m = _inPhone.firstMatch(s);
    if (m == null) return v.trim();
    return '+91${s.substring(s.length - 10)}';
  }
}
