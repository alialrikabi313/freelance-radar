import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/job_model.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';

/// يدير قائمة الوظائف — يستخدم Firestore streams للتحديث اللحظي
/// مع تطبيق الفلاتر محلياً (سريع وموثوق).
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
  Map<String, String> _jobStatuses = <String, String>{};
  Set<String> _blockedCompanies = <String>{};
  String _applicationFilter = AppConstants.appFilterAll;
  StreamSubscription<JobsPage>? _sub;
  int _displayLimit = 20;
  bool _hasMore = false;

  // آخر معاملات
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
  bool get canLoadMore => _hasMore;

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
    _jobStatuses = _cache.jobStatuses;
    _blockedCompanies = _cache.blockedCompanies;
    _applicationFilter = _cache.applicationFilter;

    _lastPlatform = platform;
    _lastCategory = category;
    _lastSortBy = sortBy;
    _lastSortOrder = sortOrder;
    _lastLanguage = language;
    _lastMinBudget = minBudget;
    _lastIncludeUnknown = includeUnknownBudget;
    _lastSearch = search;

    // عرض الكاش كـ fallback سريع
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
        .watchJobsFiltered(
      platform: platform,
      category: category,
      minBudget: minBudget > 0 ? minBudget : null,
      includeUnknownBudget: includeUnknownBudget,
      sortBy: sortBy,
      sortOrder: sortOrder,
      language: language,
      search: search,
      displayLimit: _displayLimit,
    )
        .listen(
      (page) {
        _jobs = _applyClientFilters(_decorate(page.jobs));
        _hasMore = page.hasMore;
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

  Future<void> loadMore() async {
    _displayLimit += 20;
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

  Future<void> refresh() async {
    _displayLimit = 20;
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

  Future<void> markRead(String jobId) async {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx < 0 || _jobs[idx].isRead) return;
    _jobs[idx] = _jobs[idx].copyWith(isRead: true);
    _readIds.add(jobId);
    await _cache.markRead(jobId);
    notifyListeners();
  }

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
      _jobs[idx] =
          _jobs[idx].copyWith(isFavorite: _favoriteIds.contains(job.id));
    }
    notifyListeners();
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  String getStatus(String jobId) =>
      _jobStatuses[jobId] ?? AppConstants.statusNone;

  /// تعيين حالة وظيفة (applied/interested/rejected/none).
  Future<void> setJobStatus(String jobId, String status) async {
    await _cache.setJobStatus(jobId, status);
    if (status == AppConstants.statusNone) {
      _jobStatuses.remove(jobId);
    } else {
      _jobStatuses[jobId] = status;
    }
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx >= 0) {
      _jobs[idx] = _jobs[idx].copyWith(applicationStatus: status);
    }
    // إذا فلتر "hide applied" فعّال، احذف من القائمة
    if (_applicationFilter == AppConstants.appFilterHideApplied &&
        status == AppConstants.statusApplied) {
      _jobs.removeWhere((j) => j.id == jobId);
    }
    notifyListeners();
  }

  Future<void> setApplicationFilter(String filter) async {
    if (_applicationFilter == filter) return;
    _applicationFilter = filter;
    await _cache.setApplicationFilter(filter);
    // أعد تطبيق الفلتر
    refresh();
  }

  String get applicationFilter => _applicationFilter;

  List<Job> _decorate(List<Job> source) {
    return source
        .map((j) => j.copyWith(
              isRead: _readIds.contains(j.id) ? true : j.isRead,
              isFavorite: _favoriteIds.contains(j.id) ? true : j.isFavorite,
              applicationStatus: _jobStatuses[j.id] ?? AppConstants.statusNone,
            ))
        .toList(growable: false);
  }

  List<Job> _applyClientFilters(List<Job> source) {
    var result = source;

    // فلتر الشركات المحظورة
    if (_blockedCompanies.isNotEmpty) {
      result = result
          .where((j) => !_blockedCompanies.contains(j.clientName ?? ''))
          .toList();
    }

    // فلتر حالة التقديم
    switch (_applicationFilter) {
      case AppConstants.appFilterHideApplied:
        result = result
            .where(
              (j) => j.applicationStatus != AppConstants.statusApplied &&
                  j.applicationStatus != AppConstants.statusRejected,
            )
            .toList();
        break;
      case AppConstants.appFilterOnlyApplied:
        result = result
            .where((j) => j.applicationStatus == AppConstants.statusApplied)
            .toList();
        break;
      case AppConstants.appFilterOnlyInterested:
        result = result
            .where((j) => j.applicationStatus == AppConstants.statusInterested)
            .toList();
        break;
      case AppConstants.appFilterNotReviewed:
        result = result
            .where((j) => j.applicationStatus == AppConstants.statusNone)
            .toList();
        break;
    }
    return result;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
