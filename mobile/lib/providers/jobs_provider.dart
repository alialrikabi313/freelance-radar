import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/job_model.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';

/// يدير قائمة الوظائف المقروءة من Firestore.
class JobsProvider extends ChangeNotifier {
  JobsProvider(this._firestore, this._cache);

  final FirestoreService _firestore;
  final CacheService _cache;

  List<Job> _jobs = <Job>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasMore = true;
  DateTime? _lastUpdated;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  Set<String> _readIds = <String>{};

  static const int _pageSize = 20;

  List<Job> get jobs => List.unmodifiable(_jobs);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  DateTime? get lastUpdated => _lastUpdated;

  /// الجلب الأول.
  Future<void> fetchJobs({
    required String platform,
    required String sortBy,
    required String sortOrder,
    required String language,
    required double minBudget,
    String? search,
    bool forceReload = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _hasMore = true;
    _lastDoc = null;
    notifyListeners();

    _readIds = _cache.readJobIds;

    if (_jobs.isEmpty && !forceReload) {
      final cached = _cache.getCachedJobs();
      if (cached.isNotEmpty) {
        _jobs = _applyReadStatus(cached);
        notifyListeners();
      }
    }

    try {
      final page = await _firestore.fetchJobs(
        platform: platform,
        sortBy: sortBy,
        sortOrder: sortOrder,
        language: language,
        minBudget: minBudget > 0 ? minBudget : null,
        search: search,
        limit: _pageSize,
      );
      _jobs = _applyReadStatus(page.jobs);
      _hasMore = page.hasMore;
      _lastDoc = page.lastDocument;
      _lastUpdated = await _firestore.fetchLastUpdated();
      _error = null;
      await _cache.saveCachedJobs(_jobs);
    } on FirestoreServiceException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحميل الصفحة التالية.
  Future<void> loadMore({
    required String platform,
    required String sortBy,
    required String sortOrder,
    required String language,
    required double minBudget,
    String? search,
  }) async {
    if (_isLoadingMore || !_hasMore || _isLoading || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _firestore.fetchJobs(
        platform: platform,
        sortBy: sortBy,
        sortOrder: sortOrder,
        language: language,
        minBudget: minBudget > 0 ? minBudget : null,
        search: search,
        limit: _pageSize,
        startAfter: _lastDoc,
      );
      final existing = _jobs.map((j) => j.id).toSet();
      _jobs = [
        ..._jobs,
        ..._applyReadStatus(
          page.jobs.where((j) => !existing.contains(j.id)).toList(),
        ),
      ];
      _hasMore = page.hasMore;
      _lastDoc = page.lastDocument ?? _lastDoc;
    } on FirestoreServiceException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: مع GitHub Actions، الـ refresh يقتصر على إعادة الجلب.
  Future<void> refresh({
    required String platform,
    required String sortBy,
    required String sortOrder,
    required String language,
    required double minBudget,
    String? search,
  }) async {
    await fetchJobs(
      platform: platform,
      sortBy: sortBy,
      sortOrder: sortOrder,
      language: language,
      minBudget: minBudget,
      search: search,
      forceReload: true,
    );
  }

  Future<void> markRead(String jobId) async {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx < 0 || _jobs[idx].isRead) return;
    _jobs[idx] = _jobs[idx].copyWith(isRead: true);
    _readIds.add(jobId);
    await _cache.markRead(jobId);
    notifyListeners();
  }

  List<Job> _applyReadStatus(List<Job> source) {
    if (_readIds.isEmpty) return source;
    return source
        .map((j) => _readIds.contains(j.id) ? j.copyWith(isRead: true) : j)
        .toList(growable: false);
  }
}
