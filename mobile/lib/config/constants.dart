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
  static const String kJobStatuses = 'job_statuses_v1';
  static const String kApplicationFilter = 'application_filter';
  static const String kKeywordAlerts = 'keyword_alerts';
  static const String kBlockedCompanies = 'blocked_companies';
  static const String kNotifQuietStart = 'notif_quiet_start';
  static const String kNotifQuietEnd = 'notif_quiet_end';
  static const String kNotificationsEnabled = 'notifications_enabled';
  static const String kNotificationBudget = 'notification_budget_threshold';
  static const String kNotificationIncludeUnknown =
      'notification_include_unknown_budget';
  static const String kLastNotifiedAt = 'last_notified_at';
  static const String kSelectedCategory = 'selected_category';

  // — Platforms —
  static const List<String> allPlatforms = <String>[
    'reed',
    'themuse',
    'findwork',
    'linkedin',
    'remotive',
    'remoteok',
    'weworkremotely',
    'arbeitnow',
    'workingnomads',
    'jobicy',
    'hn_jobs',
    'nodesk',
    'freelancer',
    'guru',
    'jobspresso',
    'reddit',
    'cryptojobs',
    'mostaql',
    'khamsat',
    'akhtaboot',
  ];

  static const Map<String, String> platformLabels = <String, String>{
    'all': 'الكل',
    'reed': 'Reed',
    'themuse': 'The Muse',
    'findwork': 'Findwork',
    'linkedin': 'LinkedIn',
    'remotive': 'Remotive',
    'remoteok': 'RemoteOK',
    'weworkremotely': 'WWR',
    'arbeitnow': 'Arbeitnow',
    'workingnomads': 'WorkingNomads',
    'jobicy': 'Jobicy',
    'hn_jobs': 'HN Jobs',
    'nodesk': 'NoDesk',
    'freelancer': 'Freelancer',
    'guru': 'Guru',
    'jobspresso': 'Jobspresso',
    'reddit': 'Reddit',
    'cryptojobs': 'CryptoJobs',
    'mostaql': 'مستقل',
    'khamsat': 'خمسات',
    'akhtaboot': 'أخطبوط',
  };

  static const Map<String, Color> platformColors = <String, Color>{
    'reed': Color(0xFFE60028),
    'themuse': Color(0xFF9333EA),
    'findwork': Color(0xFF06B6D4),
    'linkedin': Color(0xFF0A66C2),
    'remotive': Color(0xFFFF6B35),
    'remoteok': Color(0xFFE94F37),
    'weworkremotely': Color(0xFF2F5DE9),
    'arbeitnow': Color(0xFF34D399),
    'workingnomads': Color(0xFF0EA5E9),
    'jobicy': Color(0xFFF59E0B),
    'hn_jobs': Color(0xFFFF6600),
    'nodesk': Color(0xFF6366F1),
    'freelancer': Color(0xFF29B2FE),
    'guru': Color(0xFFEF4444),
    'jobspresso': Color(0xFFEA580C),
    'reddit': Color(0xFFFF4500),
    'cryptojobs': Color(0xFFF97316),
    'mostaql': Color(0xFF4E4BBB),
    'khamsat': Color(0xFF2EAF5C),
    'akhtaboot': Color(0xFF16A34A),
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

  // — Application statuses —
  static const String statusNone = 'none';
  static const String statusInterested = 'interested';
  static const String statusApplied = 'applied';
  static const String statusRejected = 'rejected';

  static const Map<String, String> statusLabels = <String, String>{
    statusNone: 'بدون حالة',
    statusInterested: 'مهتم',
    statusApplied: 'قدّمت',
    statusRejected: 'مرفوض/لم يناسبني',
  };

  static const Map<String, IconData> statusIcons = <String, IconData>{
    statusNone: Icons.circle_outlined,
    statusInterested: Icons.visibility_outlined,
    statusApplied: Icons.check_circle,
    statusRejected: Icons.cancel_outlined,
  };

  static const Map<String, Color> statusColors = <String, Color>{
    statusNone: Color(0xFF94A3B8),
    statusInterested: Color(0xFF3B82F6),
    statusApplied: Color(0xFF10B981),
    statusRejected: Color(0xFFEF4444),
  };

  // — Application filters —
  static const String appFilterAll = 'all';
  static const String appFilterHideApplied = 'hide_applied';
  static const String appFilterOnlyApplied = 'only_applied';
  static const String appFilterOnlyInterested = 'only_interested';
  static const String appFilterNotReviewed = 'not_reviewed';
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
