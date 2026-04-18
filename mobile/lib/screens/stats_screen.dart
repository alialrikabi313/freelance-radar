import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/job_model.dart';

/// لوحة إحصائيات: مجاميع، توزيع حسب المنصة/الفئة، متوسط الميزانية.
///
/// تقرأ من Firestore مرة واحدة عند الفتح (ليس stream) لتوفير reads.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_StatsData> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('jobs')
        .orderBy('published_at', descending: true)
        .limit(500)
        .get();
    final jobs = snap.docs.map(Job.fromFirestore).toList();
    return _StatsData.fromJobs(jobs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _fetch()),
          ),
        ],
      ),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(data: data),
              const SizedBox(height: 16),
              _SectionTitle('توزيع الفرص حسب المنصة'),
              const SizedBox(height: 8),
              _DistributionCard(
                items: data.byPlatform,
                labelResolver: (k) => AppConstants.platformLabels[k] ?? k,
                colorResolver: (k) =>
                    AppConstants.platformColors[k] ?? AppTheme.primary,
                total: data.total,
              ),
              const SizedBox(height: 16),
              _SectionTitle('توزيع الفرص حسب الفئة'),
              const SizedBox(height: 8),
              _DistributionCard(
                items: data.byCategory,
                labelResolver: (k) => AppConstants.categoryLabels[k] ?? k,
                colorResolver: (_) => AppTheme.primary,
                total: data.total,
              ),
              const SizedBox(height: 16),
              _SectionTitle('تحليل الميزانية'),
              const SizedBox(height: 8),
              _BudgetCard(data: data),
              const SizedBox(height: 16),
              _SectionTitle('الفرص المُضافة حديثاً'),
              const SizedBox(height: 8),
              _RecentActivityCard(data: data),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────── UI ──────────────────────────


class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});
  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إجمالي الفرص النشطة',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.total}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderStat(
                label: 'بميزانية',
                value: '${data.withBudget}',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 16),
              _HeaderStat(
                label: 'اليوم',
                value: '${data.last24h}',
                icon: Icons.today_outlined,
              ),
              const SizedBox(width: 16),
              _HeaderStat(
                label: 'الأسبوع',
                value: '${data.last7d}',
                icon: Icons.calendar_today_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.items,
    required this.labelResolver,
    required this.colorResolver,
    required this.total,
  });

  final List<MapEntry<String, int>> items;
  final String Function(String) labelResolver;
  final Color Function(String) colorResolver;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (final entry in items)
            _DistRow(
              label: labelResolver(entry.key),
              count: entry.value,
              total: total,
              color: colorResolver(entry.key),
            ),
        ],
      ),
    );
  }
}

class _DistRow extends StatelessWidget {
  const _DistRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$count  (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.data});
  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _row('متوسط الميزانية القصوى',
              data.avgBudget != null ? '\$${data.avgBudget!.round()}' : '—'),
          const Divider(height: 16),
          _row('أعلى ميزانية',
              data.maxBudget != null ? '\$${data.maxBudget!.round()}' : '—'),
          const Divider(height: 16),
          _row('فرص +\$1000', '${data.countOver1k}'),
          const Divider(height: 16),
          _row('فرص +\$5000', '${data.countOver5k}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.data});
  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _activityRow('آخر ساعة', data.lastHour),
          const Divider(height: 16),
          _activityRow('آخر 24 ساعة', data.last24h),
          const Divider(height: 16),
          _activityRow('آخر 7 أيام', data.last7d),
          const Divider(height: 16),
          _activityRow('آخر 30 يوم', data.last30d),
        ],
      ),
    );
  }

  Widget _activityRow(String label, int count) {
    return Row(
      children: [
        const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Data ──────────────────────────


class _StatsData {
  _StatsData({
    required this.total,
    required this.withBudget,
    required this.byPlatform,
    required this.byCategory,
    required this.avgBudget,
    required this.maxBudget,
    required this.countOver1k,
    required this.countOver5k,
    required this.lastHour,
    required this.last24h,
    required this.last7d,
    required this.last30d,
  });

  final int total;
  final int withBudget;
  final List<MapEntry<String, int>> byPlatform;
  final List<MapEntry<String, int>> byCategory;
  final double? avgBudget;
  final double? maxBudget;
  final int countOver1k;
  final int countOver5k;
  final int lastHour;
  final int last24h;
  final int last7d;
  final int last30d;

  factory _StatsData.fromJobs(List<Job> jobs) {
    final total = jobs.length;
    final budgets = jobs
        .where((j) => j.budgetMax != null)
        .map((j) => j.budgetMax!)
        .toList();

    final platformMap = <String, int>{};
    final categoryMap = <String, int>{};
    for (final j in jobs) {
      platformMap[j.platform] = (platformMap[j.platform] ?? 0) + 1;
      categoryMap[j.category] = (categoryMap[j.category] ?? 0) + 1;
    }
    final byPlatform = platformMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byCategory = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final now = DateTime.now();
    int countBefore(Duration d) => jobs
        .where((j) => now.difference(j.publishedAt).abs() <= d)
        .length;

    return _StatsData(
      total: total,
      withBudget: budgets.length,
      byPlatform: byPlatform,
      byCategory: byCategory,
      avgBudget: budgets.isEmpty
          ? null
          : budgets.reduce((a, b) => a + b) / budgets.length,
      maxBudget: budgets.isEmpty
          ? null
          : budgets.reduce((a, b) => a > b ? a : b),
      countOver1k: jobs.where((j) => (j.budgetMax ?? 0) >= 1000).length,
      countOver5k: jobs.where((j) => (j.budgetMax ?? 0) >= 5000).length,
      lastHour: countBefore(const Duration(hours: 1)),
      last24h: countBefore(const Duration(hours: 24)),
      last7d: countBefore(const Duration(days: 7)),
      last30d: countBefore(const Duration(days: 30)),
    );
  }
}
