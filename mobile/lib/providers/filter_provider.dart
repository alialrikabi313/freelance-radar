import 'package:flutter/foundation.dart';

import '../services/cache_service.dart';

/// حالة الفلاتر: المنصة، الفئة، الترتيب، اللغة، الميزانية، البحث.
class FilterProvider extends ChangeNotifier {
  FilterProvider(this._cache)
      : _sortBy = _cache.sortBy,
        _sortOrder = _cache.sortOrder,
        _language = _cache.language,
        _minBudget = _cache.minBudget,
        _selectedCategory = _cache.selectedCategory;

  final CacheService _cache;

  String _selectedPlatform = 'all';
  String _selectedCategory;
  String _sortBy;
  String _sortOrder;
  String _language;
  double _minBudget;
  bool _includeUnknownBudget = true;
  String _searchQuery = '';

  String get selectedPlatform => _selectedPlatform;
  String get selectedCategory => _selectedCategory;
  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;
  String get language => _language;
  double get minBudget => _minBudget;
  bool get includeUnknownBudget => _includeUnknownBudget;
  String get searchQuery => _searchQuery;

  void setPlatform(String platform) {
    if (_selectedPlatform == platform) return;
    _selectedPlatform = platform;
    notifyListeners();
  }

  Future<void> setCategory(String category) async {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    await _cache.setSelectedCategory(category);
    notifyListeners();
  }

  Future<void> setSortBy(String value) async {
    if (_sortBy == value) return;
    _sortBy = value;
    await _cache.setSortBy(value);
    notifyListeners();
  }

  Future<void> toggleSortOrder() async {
    _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc';
    await _cache.setSortOrder(_sortOrder);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    if (_language == value) return;
    _language = value;
    await _cache.setLanguage(value);
    notifyListeners();
  }

  Future<void> setMinBudget(double value) async {
    if (_minBudget == value) return;
    _minBudget = value;
    await _cache.setMinBudget(value);
    notifyListeners();
  }

  void setIncludeUnknownBudget(bool value) {
    if (_includeUnknownBudget == value) return;
    _includeUnknownBudget = value;
    notifyListeners();
  }

  void setSearch(String query) {
    final trimmed = query.trim();
    if (_searchQuery == trimmed) return;
    _searchQuery = trimmed;
    notifyListeners();
  }
}
