import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Widget يُعرض عند غياب نتائج أو عند وجود خطأ.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  factory EmptyState.noResults({VoidCallback? onRefresh}) => EmptyState(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج حالياً',
        subtitle: 'جرّب تغيير الفلاتر أو اضغط على تحديث لسحب فرص جديدة.',
        actionLabel: onRefresh != null ? 'تحديث الآن' : null,
        onAction: onRefresh,
      );

  factory EmptyState.error(String message, {VoidCallback? onRetry}) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'تعذّر تحميل البيانات',
        subtitle: message,
        actionLabel: onRetry != null ? 'إعادة المحاولة' : null,
        onAction: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
