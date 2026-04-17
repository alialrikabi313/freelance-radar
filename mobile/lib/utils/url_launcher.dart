import 'package:url_launcher/url_launcher.dart';

/// يفتح URL في المتصفح الخارجي.
/// يعيد true على النجاح، false إن تعذّر.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
