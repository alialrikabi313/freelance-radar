import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job_model.dart';

/// نتيجة صفحة من الوظائف.
class JobsPage {
  const JobsPage({
    required this.jobs,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Job> jobs;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

/// خدمة قراءة الوظائف من Firestore.
///
/// تدعم:
///   - جلب صفحة واحدة (fetchJobs)
///   - بث حي للوظائف (watchJobs) — للتحديث اللحظي
///   - بث حي للوظائف الجديدة فقط (watchNewJobs) — للإشعارات
class FirestoreService {
  FirestoreService({String collection = 'jobs', FirebaseFirestore? firestore})
      : _collection = collection,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String _collection;

  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  CollectionReference<Map<String, dynamic>> get _coll =>
      _db.collection(_collection);

  /// آخر وقت scraping (لعرضه في الواجهة).
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

  /// بناء الاستعلام حسب الفلاتر.
  Query<Map<String, dynamic>> _buildQuery({
    required String platform,
    required String category,
    required double? minBudget,
    required String sortBy,
    required String sortOrder,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeUnknownBudget = true,
  }) {
    Query<Map<String, dynamic>> q = _coll;

    if (platform != 'all') {
      q = q.where('platform', isEqualTo: platform);
    }
    if (category != 'all') {
      q = q.where('category', isEqualTo: category);
    }

    final hasBudgetFilter = minBudget != null && minBudget > 0;
    if (hasBudgetFilter && !includeUnknownBudget) {
      q = q.where('budget_max', isGreaterThanOrEqualTo: minBudget);
      // عند استخدام range filter، أول orderBy يجب أن يكون على نفس الحقل
      if (sortBy != 'budget_max') {
        q = q.orderBy('budget_max', descending: true);
      }
    }

    q = q.orderBy(sortBy, descending: sortOrder == 'desc');
    q = q.limit(limit);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    return q;
  }

  List<Job> _applyLocalFilters(
    List<Job> jobs, {
    required String language,
    String? search,
    double? minBudget,
    bool includeUnknownBudget = true,
  }) {
    final filtered = List<Job>.from(jobs);

    // فلتر البحث
    if (search != null && search.trim().isNotEmpty) {
      final searchLower = search.trim().toLowerCase();
      filtered.removeWhere(
        (j) =>
            !j.title.toLowerCase().contains(searchLower) &&
            !j.description.toLowerCase().contains(searchLower),
      );
    }

    // فلتر اللغة
    if (language != 'all') {
      final wantArabic = language == 'ar';
      filtered.removeWhere(
        (j) => _arabicChars.hasMatch(j.title) != wantArabic,
      );
    }

    // فلتر الميزانية مع خيار "شمل بدون ميزانية"
    if (minBudget != null && minBudget > 0 && includeUnknownBudget) {
      filtered.removeWhere((j) {
        // لو الميزانية غير معلنة، نُبقيها
        if (j.budgetMax == null) return false;
        return j.budgetMax! < minBudget;
      });
    }

    return filtered;
  }

  /// جلب صفحة وظائف (one-shot).
  Future<JobsPage> fetchJobs({
    String platform = 'all',
    String category = 'all',
    double? minBudget,
    bool includeUnknownBudget = true,
    String sortBy = 'published_at',
    String sortOrder = 'desc',
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String language = 'all',
    String? search,
  }) async {
    try {
      final fetchLimit = (language != 'all' || (search?.isNotEmpty ?? false))
          ? limit * 3
          : limit;

      final q = _buildQuery(
        platform: platform,
        category: category,
        minBudget: minBudget,
        includeUnknownBudget: includeUnknownBudget,
        sortBy: sortBy,
        sortOrder: sortOrder,
        limit: fetchLimit,
        startAfter: startAfter,
      );

      final snap = await q.get();
      var jobs = snap.docs.map(Job.fromFirestore).toList(growable: true);

      jobs = _applyLocalFilters(
        jobs,
        language: language,
        search: search,
        minBudget: minBudget,
        includeUnknownBudget: includeUnknownBudget,
      );

      final hasMore = snap.docs.length >= fetchLimit;
      if (jobs.length > limit) {
        jobs = jobs.sublist(0, limit);
      }
      final lastDoc = snap.docs.isEmpty ? null : snap.docs.last;
      return JobsPage(jobs: jobs, lastDocument: lastDoc, hasMore: hasMore);
    } on FirebaseException catch (e) {
      throw FirestoreServiceException(_messageFor(e));
    } catch (_) {
      throw FirestoreServiceException('حدث خطأ أثناء جلب البيانات');
    }
  }

  /// Stream حي لصفحة الوظائف الأولى — يحدّث فوراً عند تغير أي وظيفة.
  Stream<List<Job>> watchJobs({
    String platform = 'all',
    String category = 'all',
    double? minBudget,
    bool includeUnknownBudget = true,
    String sortBy = 'published_at',
    String sortOrder = 'desc',
    int limit = 20,
    String language = 'all',
    String? search,
  }) {
    final q = _buildQuery(
      platform: platform,
      category: category,
      minBudget: minBudget,
      includeUnknownBudget: includeUnknownBudget,
      sortBy: sortBy,
      sortOrder: sortOrder,
      // نطلب أكثر قليلاً عند وجود فلاتر محلية
      limit: (language != 'all' || (search?.isNotEmpty ?? false))
          ? limit * 3
          : limit,
    );
    return q.snapshots().map((snap) {
      var jobs = snap.docs.map(Job.fromFirestore).toList(growable: true);
      jobs = _applyLocalFilters(
        jobs,
        language: language,
        search: search,
        minBudget: minBudget,
        includeUnknownBudget: includeUnknownBudget,
      );
      if (jobs.length > limit) jobs = jobs.sublist(0, limit);
      return jobs;
    });
  }

  /// Stream للوظائف الجديدة فقط — يُستخدم في نظام الإشعارات.
  ///
  /// يُصدر فقط الوظائف المُضافة بعد [after]، ومع `budget_max >= threshold`.
  Stream<List<Job>> watchNewHighBudgetJobs({
    required DateTime after,
    required double minBudget,
    bool includeUnknownBudget = false,
  }) {
    Query<Map<String, dynamic>> q = _coll
        .where('scraped_at', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('scraped_at', descending: true)
        .limit(50);

    return q.snapshots().map((snap) {
      var jobs = snap.docs.map(Job.fromFirestore).toList();
      // فلتر الميزانية محلياً
      jobs = jobs.where((j) {
        if (j.budgetMax == null) return includeUnknownBudget;
        return j.budgetMax! >= minBudget;
      }).toList();
      return jobs;
    });
  }

  String _messageFor(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'لا توجد صلاحية للوصول. تحقق من قواعد Firestore';
      case 'unavailable':
        return 'تعذّر الوصول لـ Firestore، تحقق من الاتصال';
      case 'failed-precondition':
        return 'يحتاج الاستعلام إلى Firestore index. افتح رابط الخطأ لإنشائه';
      default:
        return e.message ?? 'حدث خطأ غير متوقع';
    }
  }
}

class FirestoreServiceException implements Exception {
  FirestoreServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
