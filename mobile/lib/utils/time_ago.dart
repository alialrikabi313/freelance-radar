import 'package:timeago/timeago.dart' as timeago;

/// تنسيق تاريخ بصيغة "منذ ساعتين".
String formatTimeAgo(DateTime date, {String locale = 'ar'}) {
  return timeago.format(date, locale: locale);
}
