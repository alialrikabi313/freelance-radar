import 'package:flutter/material.dart';

/// ثوابت التطبيق: الألوان، المنصات، مفاتيح SharedPreferences.
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

  // — Platforms —
  static const List<String> allPlatforms = <String>[
    'upwork',
    'freelancer',
    'mostaql',
    'khamsat',
  ];

  static const Map<String, String> platformLabels = <String, String>{
    'all': 'الكل',
    'upwork': 'Upwork',
    'freelancer': 'Freelancer',
    'mostaql': 'مستقل',
    'khamsat': 'خمسات',
  };

  static const Map<String, Color> platformColors = <String, Color>{
    'upwork': Color(0xFF14A800),
    'freelancer': Color(0xFF29B2FE),
    'mostaql': Color(0xFF4E4BBB),
    'khamsat': Color(0xFF2EAF5C),
  };
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
