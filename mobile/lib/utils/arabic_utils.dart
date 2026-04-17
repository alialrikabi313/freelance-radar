/// أدوات نصية للغة العربية.
class ArabicUtils {
  ArabicUtils._();

  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  /// هل النص يحتوي على حروف عربية؟
  static bool containsArabic(String text) => _arabicChars.hasMatch(text);

  /// تحويل الأرقام الإنجليزية إلى عربية.
  static String toArabicDigits(String input) {
    const map = {
      '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
      '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
    };
    final buf = StringBuffer();
    for (final c in input.split('')) {
      buf.write(map[c] ?? c);
    }
    return buf.toString();
  }
}
