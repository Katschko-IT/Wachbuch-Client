import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Öffnet eine Webseite des eigenen Servers im Browser; in Tests ersetzbar.
typedef ServerPageOpener = Future<bool> Function(Uri uri);

Future<bool> openServerPageExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
