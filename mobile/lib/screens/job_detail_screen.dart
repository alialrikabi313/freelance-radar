import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/job_model.dart';
import '../providers/jobs_provider.dart';
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
          Consumer<JobsProvider>(
            builder: (context, jobs, _) {
              final isFav = jobs.isFavorite(job.id) || job.isFavorite;
              return IconButton(
                tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : null,
                ),
                onPressed: () => jobs.toggleFavorite(job),
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
                  const SizedBox(height: 20),
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
            _OpenButton(url: job.url),
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

class _OpenButton extends StatefulWidget {
  const _OpenButton({required this.url});
  final String url;

  @override
  State<_OpenButton> createState() => _OpenButtonState();
}

class _OpenButtonState extends State<_OpenButton> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    final ok = await openExternalUrl(widget.url);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الرابط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _opening ? null : _open,
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
            label: const Text('فتح في المنصة الأصلية'),
          ),
        ),
      ),
    );
  }
}
