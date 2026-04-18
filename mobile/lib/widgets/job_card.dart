import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/job_model.dart';
import '../utils/time_ago.dart';
import 'platform_badge.dart';

/// كارد مشروع واحد في قائمة الفرص.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.onFavoriteToggle,
  });

  final Job job;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !job.isRead;

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            // شريط أزرق رفيع على اليمين (RTL → يظهر بداية الكارد)
            // يدلّ على أن المشروع غير مقروء.
          ),
          child: Stack(
            children: [
              if (isUnread)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  start: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Badge + Favorite + Budget
                    Row(
                      children: [
                        PlatformBadge(platform: job.platform),
                        const Spacer(),
                        if (onFavoriteToggle != null)
                          InkWell(
                            onTap: onFavoriteToggle,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                job.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 20,
                                color: job.isFavorite
                                    ? Colors.redAccent
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        _BudgetPill(text: job.budgetText),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (job.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        job.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (job.skills.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SkillsRow(skills: job.skills),
                    ],
                    const SizedBox(height: 10),
                    _MetaRow(job: job),
                    if (job.applicationStatus !=
                        AppConstants.statusNone) ...[
                      const SizedBox(height: 8),
                      _StatusBadge(status: job.applicationStatus),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetPill extends StatelessWidget {
  const _BudgetPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined,
              size: 14, color: AppTheme.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsRow extends StatelessWidget {
  const _SkillsRow({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final visible = skills.take(3).toList();
    final remaining = skills.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final skill in visible) _SkillChip(label: skill),
        if (remaining > 0)
          _SkillChip(label: '+$remaining', outlined: true),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, this.outlined = false});
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: outlined ? AppTheme.border : const Color(0xFFBFDBFE),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: outlined ? AppTheme.textSecondary : AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.statusColors[status] ?? AppTheme.textSecondary;
    final icon = AppConstants.statusIcons[status] ?? Icons.circle_outlined;
    final label = AppConstants.statusLabels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _metaItem(Icons.access_time, formatTimeAgo(job.publishedAt)),
      if (job.proposalsCount != null)
        _metaItem(Icons.people_outline, '${job.proposalsCount} عرض'),
      if (job.clientRating != null)
        _metaItem(
          Icons.star_rounded,
          '${job.clientRating!.toStringAsFixed(1)}'
          '${job.clientJobsPosted != null ? ' (${job.clientJobsPosted} مشروع)' : ''}',
          color: Colors.amber.shade700,
        ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: items,
    );
  }

  Widget _metaItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
