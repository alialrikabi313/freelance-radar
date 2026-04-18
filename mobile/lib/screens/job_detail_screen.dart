import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/job_model.dart';
import '../providers/jobs_provider.dart';
import '../services/cache_service.dart';
import '../utils/time_ago.dart';
import '../utils/url_launcher.dart';
import '../widgets/platform_badge.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المشروع'),
        actions: [
          IconButton(
            tooltip: 'نسخ الرابط',
            icon: const Icon(Icons.link_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: job.url));
              HapticFeedback.lightImpact();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ الرابط'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'حظر هذه الشركة',
            icon: const Icon(Icons.block_outlined),
            onPressed: () async {
              final name = job.clientName;
              if (name == null || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اسم الشركة غير متوفر')),
                );
                return;
              }
              await context.read<CacheService>().toggleBlockCompany(name);
              HapticFeedback.mediumImpact();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حظر/إلغاء حظر: $name')),
              );
            },
          ),
          Consumer<JobsProvider>(
            builder: (context, jobs, _) {
              final isFav = jobs.isFavorite(job.id) || job.isFavorite;
              return IconButton(
                tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : null,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  jobs.toggleFavorite(job);
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PlatformBadge(platform: job.platform),
                  const SizedBox(height: 14),
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _ApplicationStatusRow(jobId: job.id),
                  const SizedBox(height: 16),
                  _InfoCard(job: job),
                  const SizedBox(height: 20),
                  _SectionTitle('الوصف الكامل'),
                  const SizedBox(height: 8),
                  Text(
                    job.description.isEmpty
                        ? 'لا يوجد وصف متاح.'
                        : job.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                        ),
                  ),
                  if (job.skills.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('المهارات المطلوبة'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in job.skills)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_hasClient) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('معلومات العميل'),
                    const SizedBox(height: 8),
                    _ClientCard(job: job),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _BottomActions(url: job.url, title: job.title),
          ],
        ),
      ),
    );
  }

  bool get _hasClient =>
      job.clientName != null ||
      job.clientRating != null ||
      job.clientJobsPosted != null ||
      job.country != null;
}

class _ApplicationStatusRow extends StatelessWidget {
  const _ApplicationStatusRow({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return Consumer<JobsProvider>(
      builder: (context, jobs, _) {
        final current = jobs.getStatus(jobId);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in AppConstants.statusLabels.entries)
              if (entry.key != AppConstants.statusNone ||
                  current != AppConstants.statusNone)
                ChoiceChip(
                  avatar: Icon(
                    AppConstants.statusIcons[entry.key] ?? Icons.circle,
                    size: 16,
                    color: current == entry.key
                        ? Colors.white
                        : AppConstants.statusColors[entry.key],
                  ),
                  label: Text(entry.value),
                  selected: current == entry.key,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    jobs.setJobStatus(
                      jobId,
                      current == entry.key
                          ? AppConstants.statusNone
                          : entry.key,
                    );
                  },
                  selectedColor: AppConstants.statusColors[entry.key],
                  labelStyle: TextStyle(
                    color: current == entry.key
                        ? Colors.white
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: (AppConstants.statusColors[entry.key] ??
                              Colors.grey)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  showCheckmark: false,
                ),
          ],
        );
      },
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.job});
  final Job job;

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
          _row(
            Icons.payments_outlined,
            'الميزانية',
            job.budgetText,
            color: AppTheme.secondary,
          ),
          _divider(),
          _row(Icons.access_time, 'نُشر', formatTimeAgo(job.publishedAt)),
          if (job.proposalsCount != null) ...[
            _divider(),
            _row(
              Icons.people_outline,
              'العروض المقدمة',
              '${job.proposalsCount}',
            ),
          ],
          _divider(),
          _row(
            job.isHourly ? Icons.hourglass_bottom : Icons.flag_outlined,
            'النوع',
            job.isHourly ? 'بالساعة' : 'سعر ثابت',
          ),
          if (job.country != null) ...[
            _divider(),
            _row(Icons.public, 'بلد العميل', job.country!),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppTheme.border);
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.job});
  final Job job;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.clientName != null)
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Text(job.clientName!,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          if (job.clientRating != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 10),
                Text(
                  'التقييم: ${job.clientRating!.toStringAsFixed(1)} / 5',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (job.clientJobsPosted != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Text('مشاريع سابقة: ${job.clientJobsPosted}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomActions extends StatefulWidget {
  const _BottomActions({required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends State<_BottomActions> {
  bool _opening = false;

  Future<void> _openBrowser() async {
    setState(() => _opening = true);
    HapticFeedback.lightImpact();
    final ok = await openExternalUrl(widget.url);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الرابط')),
      );
    }
  }

  void _openPreview() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed(
      '/preview',
      arguments: {'url': widget.url, 'title': widget.title},
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _opening ? null : _openBrowser,
                  icon: _opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                  label: const Text('فتح في المتصفح'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _openPreview,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('معاينة'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
