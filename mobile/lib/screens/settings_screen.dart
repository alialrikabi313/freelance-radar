import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/filter_provider.dart';
import '../providers/jobs_provider.dart';
import '../services/cache_service.dart';
import '../services/notifications_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _enabledPlatforms;
  late double _minBudget;
  late String _language;

  // Notifications
  late bool _notifEnabled;
  late double _notifBudget;
  late bool _notifIncludeUnknown;

  @override
  void initState() {
    super.initState();
    final cache = context.read<CacheService>();
    _enabledPlatforms = List.of(cache.enabledPlatforms);
    _minBudget = cache.minBudget;
    _language = cache.language;
    _notifEnabled = cache.notificationsEnabled;
    _notifBudget = cache.notificationBudgetThreshold;
    _notifIncludeUnknown = cache.notificationIncludeUnknownBudget;
  }

  Future<void> _save() async {
    final cache = context.read<CacheService>();
    final filter = context.read<FilterProvider>();
    final notifications = context.read<NotificationsService>();

    await cache.setEnabledPlatforms(_enabledPlatforms);
    await cache.setMinBudget(_minBudget);
    await cache.setLanguage(_language);

    await cache.setNotificationBudgetThreshold(_notifBudget);
    await cache.setNotificationIncludeUnknownBudget(_notifIncludeUnknown);

    // تفعيل الإشعارات مع طلب الصلاحية
    if (_notifEnabled && !cache.notificationsEnabled) {
      final granted = await notifications.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم منح إذن الإشعارات'),
          ),
        );
        setState(() => _notifEnabled = false);
        return;
      }
    }
    await cache.setNotificationsEnabled(_notifEnabled);

    // أعد تشغيل مراقبة الإشعارات بالإعدادات الجديدة
    await notifications.start();

    await filter.setMinBudget(_minBudget);
    await filter.setLanguage(_language);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات')),
    );
  }

  Future<void> _refreshNow() async {
    await context.read<JobsProvider>().refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إعادة الجلب من Firestore')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // — Notifications —
          _SectionCard(
            title: 'إشعارات الفرص عالية القيمة 🔔',
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifEnabled,
                  onChanged: (v) => setState(() => _notifEnabled = v),
                  title: const Text('تفعيل الإشعارات'),
                  subtitle: const Text(
                    'إشعار فوري عند وصول فرصة جديدة تطابق معيار الميزانية',
                  ),
                ),
                if (_notifEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحد الأدنى للميزانية: \$${_notifBudget.round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        Slider(
                          value: _notifBudget,
                          min: 100,
                          max: 10000,
                          divisions: 99,
                          label: '\$${_notifBudget.round()}',
                          onChanged: (v) =>
                              setState(() => _notifBudget = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('\$100'),
                            Text('\$10,000'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _notifIncludeUnknown,
                    onChanged: (v) =>
                        setState(() => _notifIncludeUnknown = v),
                    title: const Text('شمل الوظائف بدون ميزانية معلنة'),
                    subtitle: const Text(
                      'مفيد لمستقل وخمسات؛ قد يزيد عدد الإشعارات',
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'ℹ️ الإشعارات تعمل عند فتح التطبيق أو أثناء تواجده في الخلفية القريبة.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // — Platforms —
          _SectionCard(
            title: 'المنصات المفعّلة',
            child: Column(
              children: [
                for (final p in AppConstants.allPlatforms)
                  SwitchListTile(
                    value: _enabledPlatforms.contains(p),
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          if (!_enabledPlatforms.contains(p)) {
                            _enabledPlatforms.add(p);
                          }
                        } else {
                          _enabledPlatforms.remove(p);
                        }
                      });
                    },
                    title: Text(AppConstants.platformLabels[p] ?? p),
                    secondary: CircleAvatar(
                      radius: 6,
                      backgroundColor: AppConstants.platformColors[p],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // — Min budget for filter —
          _SectionCard(
            title: 'الحد الأدنى للميزانية (\$) — فلتر افتراضي',
            child: Column(
              children: [
                Slider(
                  value: _minBudget,
                  min: 0,
                  max: 5000,
                  divisions: 50,
                  label: _minBudget.round().toString(),
                  onChanged: (v) => setState(() => _minBudget = v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('0'),
                      Text(
                        '\$${_minBudget.round()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Text('\$5000'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // — Language —
          _SectionCard(
            title: 'لغة المشاريع',
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'all',
                  groupValue: _language,
                  onChanged: (v) => setState(() => _language = v!),
                  title: const Text('الكل'),
                ),
                RadioListTile<String>(
                  value: 'ar',
                  groupValue: _language,
                  onChanged: (v) => setState(() => _language = v!),
                  title: const Text('عربي فقط'),
                ),
                RadioListTile<String>(
                  value: 'en',
                  groupValue: _language,
                  onChanged: (v) => setState(() => _language = v!),
                  title: const Text('إنجليزي فقط'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // — Data source —
          _SectionCard(
            title: 'مصدر البيانات',
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined,
                      color: AppTheme.secondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'التحديث اللحظي مفعّل. GitHub Actions يسحب فرصاً جديدة كل 30 دقيقة.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshNow,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة الجلب من Firestore'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'FreelanceRadar — الإصدار 1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
