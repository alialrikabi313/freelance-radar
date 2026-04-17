// Smoke test بسيط — يتأكد من تحميل الثوابت دون أخطاء.
import 'package:flutter_test/flutter_test.dart';

import 'package:freelance_radar/config/constants.dart';

void main() {
  test('Platform labels and colors cover all platforms', () {
    for (final p in AppConstants.allPlatforms) {
      expect(AppConstants.platformLabels.containsKey(p), isTrue);
      expect(AppConstants.platformColors.containsKey(p), isTrue);
    }
  });
}
