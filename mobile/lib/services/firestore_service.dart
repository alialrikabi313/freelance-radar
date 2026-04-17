import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job_model.dart';

/// نتيجة صفحة من الوظائف.
class JobsPage {
  const JobsPage({
    required this.jobs,
    required this.hasMore,
  });

  final List<Job> jobs;
  final bool hasMore;
}

/// خدمة قراءة الوظائف من Firestore.
///
/// الاستراتيجية: نجلب أحدث 500 وظيفة مرة واحدة عبر stream،
/// ثم نطبّق كل الفلاتر محلياً. هذا:
///   - يتجنب الحاجة لـ composite indexes معقدة
///   - يعطي تحديث لحظي (Firestore streams)
///   - أسرع بكثير للمستخدم (فلترة فورية عند تغيير أي chip)
///   - ضمن حدود free tier بسهولة
class FirestoreService {
  FirestoreService({String collection = 'jobs', FirebaseFirestore? firestore})
      : _collection = collection,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String _collection;

  /// الحد الأقصى للجلب — يكفي لأكثر من 30 يوم من البيانات.
  static const int _maxJobsPerFetch = 500;

  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  CollectionReference<Map<String, dynamic>> get _coll =>
      _db.collection(_collection);

  /// آخر وقت scraping.
  Future<DateTime?> fetchLastUpdated() async {
    try {
      final snap = await _coll
          .orderBy('scraped_at', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final ts = snap.docs.first.data()['scraped_at'];
      if (ts is Timestamp) return ts.toDate();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// يطبّق الفلاتر محلياً على قائمة وظائف.
  List<Job> _applyFilters(
    List<Job> source, {
    required String platform,
    required String category,
    required double? minBudget,
    required bool includeUnknownBudget,
    required String language,
    required String sortBy,
    required String sortOrder,
    String? search,
  }) {
    var result = List<Job>.from(source);

    // 1. فلتر المنصة
    if (platform != 'all') {
      result = result.where((j) => j.platform == platform).toList();
    }

    // 2. فلتر الفئة
    if (category != 'all') {
      result = result.where((j) => j.category == category).toList();
    }

    // 3. فلتر الميزانية
    if (minBudget != null && minBudget > 0) {
      result = result.where((j) {
        if (j.budgetMax == null) return includeUnknownBudget;
        return j.budgetMax! >= minBudget;
      }).toList();
    }

    // 4. فلتر اللغة
    if (language != 'all') {
      final wantArabic = language == 'ar';
      result = result
          .where((j) => _arabicChars.hasMatch(j.title) == wantArabic)
          .toList();
    }

    // 5. فلتر البحث
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result
          .where(
            (j) =>
                j.title.toLowerCase().contains(q) ||
                j.description.toLowerCase().contains(q),
          )
          .toList();
    }

    // 6. الترتيب
    final desc = sortOrder == 'desc';
    result.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case 'relevance_score':
          cmp = a.relevanceScore.compareTo(b.relevanceScore);
          break;
        case 'budget_max':
          final av = a.budgetMax ?? -1;
          final bv = b.budgetMax ?? -1;
          cmp = av.compareTo(bv);
          break;
        case 'published_at':
        default:
          cmp = a.publishedAt.compareTo(b.publishedAt);
      }
      return desc ? -cmp : cmp;
    });

    return result;
  }

  /// Stream حي لكل الوظائف (محدّد بـ 500) — يُحدّث لحظياً.
  /// يُرجع [JobsPage] بعد تطبيق الفلاتر محلياً.
  Stream<JobsPage> watchJobsFiltered({
    String platform = 'all',
    String category = 'all',
    double? minBudget,
    bool includeUnknownBudget = true,
    String sortBy = 'published_at',
    String sortOrder = 'desc',
    int displayLimit = 20,
    String language = 'all',
    String? search,
  }) {
    // استعلام بسيط: فقط orderBy + limit (لا يحتاج composite index)
    final q = _coll
        .orderBy('published_at', descending: true)
        .limit(_maxJobsPerFetch);

    return q.snapshots().map((snap) {
      final all = snap.docs.map(Job.fromFirestore).toList();
      final filtered = _applyFilters(
        all,
        platform: platform,
        category: category,
        minBudget: minBudget,
        includeUnknownBudget: includeUnknownBudget,
        language: language,
        sortBy: sortBy,
        sortOrder: sortOrder,
        search: search,
      );
      final visible = filtered.length > displayLimit
          ? filtered.sublist(0, displayLimit)
          : filtered;
      return JobsPage(
        jobs: visible,
        hasMore: filtered.length > displayLimit,
      );
    });
  }

  /// Stream للوظائف الجديدة فقط (للإشعارات).
  Stream<List<Job>> watchNewHighBudgetJobs({
    required DateTime after,
    required double minBudget,
    bool includeUnknownBudget = false,
  }) {
    final q = _coll
        .where('scraped_at', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('scraped_at', descending: true)
        .limit(50);

    return q.snapshots().map((snap) {
      var jobs = snap.docs.map(Job.fromFirestore).toList();
      jobs = jobs.where((j) {
        if (j.budgetMax == null) return includeUnknownBudget;
        return j.budgetMax! >= minBudget;
      }).toList();
      return jobs;
    });
  }
}

class FirestoreServiceException implements Exception {
  FirestoreServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
