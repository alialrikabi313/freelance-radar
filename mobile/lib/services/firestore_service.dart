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
/// تستخدم cursor-based pagination عبر startAfterDocument
/// لتقليل قراءات الـ free tier.
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

  /// جلب صفحة وظائف من Firestore.
  ///
  /// نطبّق فلتر اللغة بعد الجلب لأنها لا تُخزّن كحقل منفصل.
  Future<JobsPage> fetchJobs({
    String platform = 'all',
    double? minBudget,
    String sortBy = 'published_at',
    String sortOrder = 'desc',
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String language = 'all',
    String? search,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _coll;

      if (platform != 'all') {
        q = q.where('platform', isEqualTo: platform);
      }
      if (minBudget != null && minBudget > 0) {
        q = q.where('budget_max', isGreaterThanOrEqualTo: minBudget);
        // عند استخدام range filter يجب الـ orderBy بنفس الحقل أولاً
        if (sortBy != 'budget_max') {
          q = q.orderBy('budget_max', descending: true);
        }
      }

      q = q.orderBy(sortBy, descending: sortOrder == 'desc');

      // نطلب limit إضافي لاستبعاد ما لا يطابق الفلاتر المحلية لاحقاً
      // ثم نقتطع
      final fetchLimit = (language != 'all' || (search?.isNotEmpty ?? false))
          ? limit * 3
          : limit;
      q = q.limit(fetchLimit);

      if (startAfter != null) {
        q = q.startAfterDocument(startAfter);
      }

      final snap = await q.get();
      var jobs = snap.docs.map(Job.fromFirestore).toList(growable: true);

      // فلتر اللغة محلياً
      if (language != 'all') {
        final wantArabic = language == 'ar';
        jobs.removeWhere(
          (j) => _arabicChars.hasMatch(j.title) != wantArabic,
        );
      }

      // فلتر البحث محلياً
      if (search != null && search.trim().isNotEmpty) {
        final searchLower = search.trim().toLowerCase();
        jobs.removeWhere(
          (j) =>
              !j.title.toLowerCase().contains(searchLower) &&
              !j.description.toLowerCase().contains(searchLower),
        );
      }

      // اقتطع للحدّ المطلوب
      final hasMore = snap.docs.length >= fetchLimit;
      if (jobs.length > limit) {
        jobs = jobs.sublist(0, limit);
      }

      final lastDoc = snap.docs.isEmpty ? null : snap.docs.last;
      return JobsPage(jobs: jobs, lastDocument: lastDoc, hasMore: hasMore);
    } on FirebaseException catch (e) {
      throw FirestoreServiceException(_messageFor(e));
    } catch (e) {
      throw FirestoreServiceException('حدث خطأ أثناء جلب البيانات');
    }
  }

  String _messageFor(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'لا توجد صلاحية للوصول. تحقق من قواعد Firestore';
      case 'unavailable':
        return 'تعذّر الوصول لـ Firestore، تحقق من الاتصال';
      case 'failed-precondition':
        return 'يحتاج الاستعلام إلى Firestore index. افتح الرابط في الـ console لإنشائه';
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
