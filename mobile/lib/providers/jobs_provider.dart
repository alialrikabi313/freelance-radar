import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/job_model.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';

/// يدير قائمة الوظائف — يستخدم Firestore streams للتحديث اللحظي.
///
/// عند أي تغيير في الفلاتر، تُعاد تهيئة الـ subscription بالمعاملات الجديدة.
class JobsProvider extends ChangeNotifier {
  JobsProvider(this._firestore, this._cache);

  final FirestoreService _firestore;
  final CacheService _cache;

  List<Job> _jobs = <Job>[];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  Set<String> _readIds = <String>{};
  Set<String> _favoriteIds = <String>{};
  StreamSubscription<List<Job>>? _sub;
  int _currentLimit = 20;

  // آخر معاملات مُستخدمة (لاستعادة الاشتراك)
  String _lastPlatform = 'all';
  String _lastCategory = 'all';
  String _lastSortBy = 'published_at';
  String _lastSortOrder = 'desc';
  String _lastLanguage = 'all';
  double _lastMinBudget = 0;
  bool _lastIncludeUnknown = true;
  String? _lastSearch;

  List<Job> get jobs => List.unmodifiable(_jobs);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get canLoadMore => _jobs.length >= _currentLimit;

  /// تشغيل الـ stream بالمعاملات المعطاة.
  void subscribe({
    required String platform,
    required String category,
    required String sortBy,
    required String sortOrder,
    required String language,
    required double minBudget,
    required bool includeUnknownBudget,
    String? search,
  }) {
    _readIds = _cache.readJobIds;
    _favoriteIds = _cache.favoriteJobIds;

    _lastPlatform = platform;
    _lastCategory = category;
    _lastSortBy = sortBy;
    _lastSortOrder = sortOrder;
    _lastLanguage = language;
    _lastMinBudget = minBudget;
    _lastIncludeUnknown = includeUnknownBudget;
    _lastSearch = search;

    // عرض الكاش كـ fallback سريع.
    if (_jobs.isEmpty) {
      final cached = _cache.getCachedJobs();
      if (cached.isNotEmpty) {
        _jobs = _decorate(cached);
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _sub?.cancel();
    _sub = _firestore
        .watchJobs(
      platform: platform,
      category: category,
      minBudget: minBudget > 0 ? minBudget : null,
      includeUnknownBudget: includeUnknownBudget,
      sortBy: sortBy,
      sortOrder: sortOrder,
      language: language,
      search: search,
      limit: _currentLimit,
    )
        .listen(
      (newJobs) {
        _jobs = _decorate(newJobs);
        _isLoading = false;
        _error = null;
        notifyListeners();
        _cache.saveCachedJobs(_jobs);
        _refreshLastUpdated();
      },
      onError: (err) {
        _error = err is FirestoreServiceException
            ? err.message
            : 'حدث خطأ أثناء جلب البيانات';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// تحميل المزيد — نزيد الحد الأقصى ونعيد الاشتراك.
  Future<void> loadMore() async {
    _currentLimit += 20;
    subscribe(
      platform: _lastPlatform,
      category: _lastCategory,
      sortBy: _lastSortBy,
      sortOrder: _lastSortOrder,
      language: _lastLanguage,
      minBudget: _lastMinBudget,
      includeUnknownBudget: _lastIncludeUnknown,
      search: _lastSearch,
    );
  }

  /// سحب للتحديث — مع streams يكفي إعادة الاشتراك.
  Future<void> refresh() async {
    _currentLimit = 20;
    subscribe(
      platform: _lastPlatform,
      category: _lastCategory,
      sortBy: _lastSortBy,
      sortOrder: _lastSortOrder,
      language: _lastLanguage,
      minBudget: _lastMinBudget,
      includeUnknownBudget: _lastIncludeUnknown,
      search: _lastSearch,
    );
  }

  Future<void> _refreshLastUpdated() async {
    _lastUpdated = await _firestore.fetchLastUpdated();
    notifyListeners();
  }

  /// علّم وظيفة مقروءة محلياً.
  Future<void> markRead(String jobId) async {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx < 0 || _jobs[idx].isRead) return;
    _jobs[idx] = _jobs[idx].copyWith(isRead: true);
    _readIds.add(jobId);
    await _cache.markRead(jobId);
    notifyListeners();
  }

  /// تبديل حالة المفضلة.
  Future<void> toggleFavorite(Job job) async {
    await _cache.toggleFavorite(job.id);
    if (_favoriteIds.contains(job.id)) {
      _favoriteIds.remove(job.id);
      await _cache.removeFavoriteData(job.id);
    } else {
      _favoriteIds.add(job.id);
      await _cache.saveFavoriteJob(job);
    }
    final idx = _jobs.indexWhere((j) => j.id == job.id);
    if (idx >= 0) {
      _jobs[idx] = _jobs[idx].copyWith(isFavorite: _favoriteIds.contains(job.id));
    }
    notifyListeners();
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  List<Job> _decorate(List<Job> source) {
    if (_readIds.isEmpty && _favoriteIds.isEmpty) return source;
    return source
        .map((j) => j.copyWith(
              isRead: _readIds.contains(j.id) ? true : j.isRead,
              isFavorite: _favoriteIds.contains(j.id) ? true : j.isFavorite,
            ))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
