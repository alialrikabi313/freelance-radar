import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/job_model.dart';

/// يدير الإعدادات المحفوظة محلياً، كاش الوظائف، المفضلة،
/// والمقروءة — جميعها محلياً على الجهاز.
class CacheService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('CacheService.init() لم تُستدعَ بعد');
    }
    return p;
  }

  // ───────────── Platforms ─────────────

  List<String> get enabledPlatforms {
    final saved = _p.getStringList(AppConstants.kEnabledPlatforms);
    return saved ?? AppConstants.allPlatforms;
  }

  Future<void> setEnabledPlatforms(List<String> list) =>
      _p.setStringList(AppConstants.kEnabledPlatforms, list);

  // ───────────── Budget ─────────────

  double get minBudget => _p.getDouble(AppConstants.kMinBudget) ?? 0.0;
  Future<void> setMinBudget(double v) =>
      _p.setDouble(AppConstants.kMinBudget, v);

  // ───────────── Language ─────────────

  String get language => _p.getString(AppConstants.kLanguage) ?? 'all';
  Future<void> setLanguage(String v) =>
      _p.setString(AppConstants.kLanguage, v);

  // ───────────── Sort ─────────────

  String get sortBy =>
      _p.getString(AppConstants.kSortBy) ?? 'published_at';
  Future<void> setSortBy(String v) => _p.setString(AppConstants.kSortBy, v);

  String get sortOrder => _p.getString(AppConstants.kSortOrder) ?? 'desc';
  Future<void> setSortOrder(String v) =>
      _p.setString(AppConstants.kSortOrder, v);

  // ───────────── Category ─────────────

  String get selectedCategory =>
      _p.getString(AppConstants.kSelectedCategory) ?? 'all';
  Future<void> setSelectedCategory(String v) =>
      _p.setString(AppConstants.kSelectedCategory, v);

  // ───────────── Read job IDs (محلي) ─────────────

  Set<String> get readJobIds {
    final saved = _p.getStringList(AppConstants.kReadJobIds);
    return saved == null ? <String>{} : saved.toSet();
  }

  Future<void> markRead(String id) async {
    final s = readJobIds..add(id);
    final list = s.toList();
    if (list.length > 500) {
      list.removeRange(0, list.length - 500);
    }
    await _p.setStringList(AppConstants.kReadJobIds, list);
  }

  // ───────────── Favorites (محلي) ─────────────

  Set<String> get favoriteJobIds {
    final saved = _p.getStringList(AppConstants.kFavoriteJobIds);
    return saved == null ? <String>{} : saved.toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final s = favoriteJobIds;
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    await _p.setStringList(AppConstants.kFavoriteJobIds, s.toList());
  }

  Future<void> saveFavoriteJob(Job job) async {
    // نخزّن نسخة كاملة عن الوظيفة المفضّلة كي تبقى متاحة
    // حتى لو حُذفت من Firestore بعد 30 يوم.
    final raw = _p.getString('fav_data_${job.id}');
    if (raw == null) {
      await _p.setString('fav_data_${job.id}', json.encode(job.toJson()));
    }
  }

  Future<Job?> getFavoriteJob(String id) async {
    final raw = _p.getString('fav_data_$id');
    if (raw == null) return null;
    try {
      return Job.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeFavoriteData(String id) async {
    await _p.remove('fav_data_$id');
  }

  Future<List<Job>> getAllFavoriteJobs() async {
    final ids = favoriteJobIds;
    final result = <Job>[];
    for (final id in ids) {
      final j = await getFavoriteJob(id);
      if (j != null) result.add(j.copyWith(isFavorite: true));
    }
    return result;
  }

  // ───────────── Notifications settings ─────────────

  bool get notificationsEnabled =>
      _p.getBool(AppConstants.kNotificationsEnabled) ?? false;
  Future<void> setNotificationsEnabled(bool v) =>
      _p.setBool(AppConstants.kNotificationsEnabled, v);

  double get notificationBudgetThreshold =>
      _p.getDouble(AppConstants.kNotificationBudget) ?? 1000.0;
  Future<void> setNotificationBudgetThreshold(double v) =>
      _p.setDouble(AppConstants.kNotificationBudget, v);

  bool get notificationIncludeUnknownBudget =>
      _p.getBool(AppConstants.kNotificationIncludeUnknown) ?? false;
  Future<void> setNotificationIncludeUnknownBudget(bool v) =>
      _p.setBool(AppConstants.kNotificationIncludeUnknown, v);

  DateTime get lastNotifiedAt {
    final ms = _p.getInt(AppConstants.kLastNotifiedAt);
    if (ms == null) {
      // أول مرة: نرجع الآن لكي لا ينفجر إشعار لكل الوظائف الحالية.
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastNotifiedAt(DateTime t) =>
      _p.setInt(AppConstants.kLastNotifiedAt, t.millisecondsSinceEpoch);

  // ───────────── Cached jobs (offline) ─────────────

  List<Job> getCachedJobs() {
    final raw = _p.getString(AppConstants.kCachedJobs);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .map((e) => Job.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCachedJobs(List<Job> jobs) async {
    final slice = jobs.take(100).map((j) => j.toJson()).toList();
    await _p.setString(AppConstants.kCachedJobs, json.encode(slice));
  }
}
