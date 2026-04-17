import 'package:flutter/material.dart';

/// ثوابت التطبيق: الألوان، المنصات، الفئات، مفاتيح SharedPreferences.
class AppConstants {
  AppConstants._();

  // — Firestore —
  static const String firestoreCollection = 'jobs';

  // — SharedPreferences keys —
  static const String kEnabledPlatforms = 'enabled_platforms';
  static const String kMinBudget = 'min_budget';
  static const String kLanguage = 'language';
  static const String kSortBy = 'sort_by';
  static const String kSortOrder = 'sort_order';
  static const String kCachedJobs = 'cached_jobs_v1';
  static const String kReadJobIds = 'read_job_ids';
  static const String kFavoriteJobIds = 'favorite_job_ids';
  static const String kNotificationsEnabled = 'notifications_enabled';
  static const String kNotificationBudget = 'notification_budget_threshold';
  static const String kNotificationIncludeUnknown =
      'notification_include_unknown_budget';
  static const String kLastNotifiedAt = 'last_notified_at';
  static const String kSelectedCategory = 'selected_category';

  // — Platforms —
  static const List<String> allPlatforms = <String>[
    'remotive',
    'freelancer',
    'mostaql',
    'khamsat',
  ];

  static const Map<String, String> platformLabels = <String, String>{
    'all': 'الكل',
    'remotive': 'Remotive',
    'freelancer': 'Freelancer',
    'mostaql': 'مستقل',
    'khamsat': 'خمسات',
  };

  static const Map<String, Color> platformColors = <String, Color>{
    'remotive': Color(0xFFFF6B35),
    'freelancer': Color(0xFF29B2FE),
    'mostaql': Color(0xFF4E4BBB),
    'khamsat': Color(0xFF2EAF5C),
  };

  // — Categories —
  static const List<String> allCategories = <String>[
    'all',
    'mobile',
    'web',
    'backend',
    'ai',
    'game',
    'data',
    'blockchain',
    'desktop',
    'other',
  ];

  static const Map<String, String> categoryLabels = <String, String>{
    'all': 'الكل',
    'mobile': 'موبايل',
    'web': 'ويب',
    'backend': 'خادم/API',
    'ai': 'ذكاء اصطناعي',
    'game': 'ألعاب',
    'data': 'بيانات',
    'blockchain': 'بلوكتشين',
    'desktop': 'سطح مكتب',
    'other': 'أخرى',
  };

  static const Map<String, IconData> categoryIcons = <String, IconData>{
    'all': Icons.apps,
    'mobile': Icons.phone_android,
    'web': Icons.web,
    'backend': Icons.dns_outlined,
    'ai': Icons.psychology_outlined,
    'game': Icons.sports_esports,
    'data': Icons.bar_chart,
    'blockchain': Icons.link,
    'desktop': Icons.desktop_windows_outlined,
    'other': Icons.code,
  };

  // — Quick budget thresholds (USD) —
  static const List<int> budgetThresholds = <int>[0, 500, 1000, 2000, 5000];
}

/// خيارات الترتيب المتاحة.
class SortOption {
  const SortOption(this.value, this.label);
  final String value;
  final String label;

  static const List<SortOption> all = [
    SortOption('published_at', 'الأحدث'),
    SortOption('relevance_score', 'الأكثر صلة'),
    SortOption('budget_max', 'الأعلى ميزانية'),
  ];
}
