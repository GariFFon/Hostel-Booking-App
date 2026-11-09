import 'package:url_launcher/url_launcher.dart';

/// Opens the platform maps app (Google Maps on Android, Apple/Google Maps on iOS) at a point. Returns false if nothing could handle it.
Future<bool> openMaps(double latitude, double longitude, {String? label}) {
  final q = label == null ? '$latitude,$longitude' : Uri.encodeComponent('$label @ $latitude,$longitude');
  return launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), mode: LaunchMode.externalApplication);
}

/// Opens the dialer. The number is the property's own, shown only after a booking is confirmed.
Future<bool> callPhone(String number) => launchUrl(Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[^\d+]'), '')));

Future<bool> openEmail(String address) => launchUrl(Uri(scheme: 'mailto', path: address));
