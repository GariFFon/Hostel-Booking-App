/// Pulls the invitation token out of whatever the person pasted: the bare code, or the whole link from the email
/// (`https://site/staff?invite=CODE`). Returns null when it cannot be a token.
String? parseInviteToken(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final fromLink = uri?.queryParameters['invite'];
  if (fromLink != null && fromLink.isNotEmpty) text = fromLink;
  text = text.trim();
  // A real token is long and made of URL-safe characters only.
  if (text.length < 20 || text.length > 200) return null;
  if (!RegExp(r'^[A-Za-z0-9_\-.~%]+$').hasMatch(text)) return null;
  try {
    return Uri.decodeComponent(text);
  } catch (_) {
    return null;
  }
}
