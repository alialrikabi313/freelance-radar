import 'package:cloud_firestore/cloud_firestore.dart';

/// موديل المشروع.
class Job {
  const Job({
    required this.id,
    required this.platform,
    required this.title,
    required this.description,
    required this.url,
    required this.publishedAt,
    required this.scrapedAt,
    required this.currency,
    required this.skills,
    required this.isHourly,
    required this.relevanceScore,
    required this.isRead,
    required this.category,
    required this.isFavorite,
    this.budgetMin,
    this.budgetMax,
    this.clientName,
    this.clientRating,
    this.clientJobsPosted,
    this.proposalsCount,
    this.country,
  });

  final String id;
  final String platform;
  final String title;
  final String description;
  final double? budgetMin;
  final double? budgetMax;
  final String currency;
  final List<String> skills;
  final String? clientName;
  final double? clientRating;
  final int? clientJobsPosted;
  final int? proposalsCount;
  final String url;
  final DateTime publishedAt;
  final DateTime scrapedAt;
  final bool isHourly;
  final double relevanceScore;
  final bool isRead;
  final String category;
  final bool isFavorite;
  final String? country;

  factory Job.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Job(
      id: doc.id,
      platform: (data['platform'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      budgetMin: _toDouble(data['budget_min']),
      budgetMax: _toDouble(data['budget_max']),
      currency: (data['currency'] ?? 'USD') as String,
      skills: ((data['skills'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      clientName: data['client_name'] as String?,
      clientRating: _toDouble(data['client_rating']),
      clientJobsPosted: _toInt(data['client_jobs_posted']),
      proposalsCount: _toInt(data['proposals_count']),
      url: (data['url'] ?? '') as String,
      publishedAt: _toDate(data['published_at']) ?? DateTime.now(),
      scrapedAt: _toDate(data['scraped_at']) ?? DateTime.now(),
      isHourly: (data['is_hourly'] ?? false) as bool,
      relevanceScore: _toDouble(data['relevance_score']) ?? 0.0,
      isRead: false, // محلية فقط
      isFavorite: false, // محلية فقط
      category: (data['category'] ?? 'other') as String,
      country: data['country'] as String?,
    );
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: (json['id'] ?? '') as String,
      platform: (json['platform'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      budgetMin: _toDouble(json['budget_min']),
      budgetMax: _toDouble(json['budget_max']),
      currency: (json['currency'] ?? 'USD') as String,
      skills: ((json['skills'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      clientName: json['client_name'] as String?,
      clientRating: _toDouble(json['client_rating']),
      clientJobsPosted: _toInt(json['client_jobs_posted']),
      proposalsCount: _toInt(json['proposals_count']),
      url: (json['url'] ?? '') as String,
      publishedAt: _toDate(json['published_at']) ?? DateTime.now(),
      scrapedAt: _toDate(json['scraped_at']) ?? DateTime.now(),
      isHourly: (json['is_hourly'] ?? false) as bool,
      relevanceScore: _toDouble(json['relevance_score']) ?? 0.0,
      isRead: (json['is_read'] ?? false) as bool,
      isFavorite: (json['is_favorite'] ?? false) as bool,
      category: (json['category'] ?? 'other') as String,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'title': title,
        'description': description,
        'budget_min': budgetMin,
        'budget_max': budgetMax,
        'currency': currency,
        'skills': skills,
        'client_name': clientName,
        'client_rating': clientRating,
        'client_jobs_posted': clientJobsPosted,
        'proposals_count': proposalsCount,
        'url': url,
        'published_at': publishedAt.toIso8601String(),
        'scraped_at': scrapedAt.toIso8601String(),
        'is_hourly': isHourly,
        'relevance_score': relevanceScore,
        'is_read': isRead,
        'is_favorite': isFavorite,
        'category': category,
        'country': country,
      };

  /// نص الميزانية المعروض في الكارد.
  String get budgetText {
    String symbol;
    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'SAR':
        symbol = 'ر.س';
        break;
      case 'AED':
        symbol = 'د.إ';
        break;
      case 'EGP':
        symbol = 'ج.م';
        break;
      default:
        symbol = currency;
    }
    if (budgetMin == null && budgetMax == null) return '—';
    final lo = budgetMin?.round();
    final hi = budgetMax?.round();
    final suffix = isHourly ? ' / ساعة' : '';
    if (lo == null) return '$symbol$hi$suffix';
    if (hi == null || hi == lo) return '$symbol$lo$suffix';
    return '$symbol$lo - $symbol$hi$suffix';
  }

  Job copyWith({bool? isRead, bool? isFavorite}) => Job(
        id: id,
        platform: platform,
        title: title,
        description: description,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        currency: currency,
        skills: skills,
        clientName: clientName,
        clientRating: clientRating,
        clientJobsPosted: clientJobsPosted,
        proposalsCount: proposalsCount,
        url: url,
        publishedAt: publishedAt,
        scrapedAt: scrapedAt,
        isHourly: isHourly,
        relevanceScore: relevanceScore,
        isRead: isRead ?? this.isRead,
        isFavorite: isFavorite ?? this.isFavorite,
        category: category,
        country: country,
      );
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.tryParse(v.toString());
}
