import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/job_model.dart';

/// يدير الإعدادات المحفوظة محلياً وكاش الوظائف لعرضها offline
/// وكذلك حالة "مقروءة" لكل وظيفة (محلية على الجهاز).
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

  // ───────────── Enabled platforms ─────────────

  List<String> get enabledPlatforms {
    final saved = _p.getStringList(AppConstants.kEnabledPlatforms);
    return saved ?? AppConstants.allPlatforms;
  }

  Future<void> setEnabledPlatforms(List<String> list) =>
      _p.setStringList(AppConstants.kEnabledPlatforms, list);

  // ───────────── Min budget ─────────────

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

  String get sortOrder =>
      _p.getString(AppConstants.kSortOrder) ?? 'desc';

  Future<void> setSortOrder(String v) =>
      _p.setString(AppConstants.kSortOrder, v);

  // ───────────── Read jobs (محلي) ─────────────

  Set<String> get readJobIds {
    final saved = _p.getStringList(AppConstants.kReadJobIds);
    return saved == null ? <String>{} : saved.toSet();
  }

  Future<void> markRead(String id) async {
    final s = readJobIds..add(id);
    // نحتفظ بأحدث 500 معرف فقط لتجنب نمو غير محدود
    final list = s.toList();
    if (list.length > 500) {
      list.removeRange(0, list.length - 500);
    }
    await _p.setStringList(AppConstants.kReadJobIds, list);
  }

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
