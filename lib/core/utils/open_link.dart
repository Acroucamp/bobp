import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web link robustly. Tries the external browser first, then falls
/// back to an in-app browser view. Returns true if either worked.
Future<bool> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return false;
  }
  for (final mode in const [
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
    LaunchMode.platformDefault,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return true;
    } catch (e) {
      debugPrint('openLink($mode) failed: $e');
    }
  }
  return false;
}
