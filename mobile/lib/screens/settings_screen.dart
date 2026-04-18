import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/routes.dart';
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

  late bool _notifEnabled;
  late double _notifBudget;
  late bool _notifIncludeUnknown;
  late TextEditingController _keywordsCtrl;
  late int _quietStart;
  late int _quietEnd;

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
    _keywordsCtrl = TextEditingController(
      text: cache.keywordAlerts.join(', '),
    );
    _quietStart = cache.notifQuietStart;
    _quietEnd = cache.notifQuietEnd;
  }

  @override
  void dispose() {
    _keywordsCtrl.dispose();
    super.dispose();
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
    await cache.setNotifQuietHours(_quietStart, _quietEnd);

    // keywords: نفصل بـ comma أو newline
    final keywords = _keywordsCtrl.text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await cache.setKeywordAlerts(keywords);

    if (_notifEnabled && !cache.notificationsEnabled) {
      final granted = await notifications.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم منح إذن الإشعارات')),
        );
        setState(() => _notifEnabled = false);
        return;
      }
    }
    await cache.setNotificationsEnabled(_notifEnabled);
    await notifications.start();

    await filter.setMinBudget(_minBudget);
    await filter.setLanguage(_language);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات')),
    );
  }

  Future<void> _pickQuietHour(bool start) async {
    final current = start ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current >= 0 ? current : 22, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _quietStart = picked.hour;
      } else {
        _quietEnd = picked.hour;
      }
    });
  }

  String _fmtHour(int h) =>
      h < 0 ? '—' : '${h.toString().padLeft(2, '0')}:00';

  Future<void> _refreshNow() async {
    await context.read<JobsProvider>().refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إعادة الجلب من Firestore')),
    );
  }

  Future<void> _clearBlocked() async {
    await context.read<CacheService>().clearBlockedCompanies();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إلغاء حظر جميع الشركات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = context.read<CacheService>().blockedCompanies;

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
          // — Stats shortcut —
          _SectionCard(
            title: 'لوحة الإحصائيات 📊',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.stats),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('عرض الإحصائيات التفصيلية'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // — Notifications —
          _SectionCard(
            title: 'إشعارات الفرص الساخنة 🔔',
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifEnabled,
                  onChanged: (v) => setState(() => _notifEnabled = v),
                  title: const Text('تفعيل الإشعارات'),
                  subtitle: const Text(
                    'إشعار فوري عند وصول فرصة تطابق معاييرك',
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
                          onChanged: (v) => setState(() => _notifBudget = v),
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
                      'مفيد لمستقل وخمسات (قد يزيد عدد الإشعارات)',
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الكلمات المفتاحية (keyword alerts)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'اكتب كلمات/مهارات تهمك، افصلها بفاصلة. '
                          'سيصلك إشعار فقط لو ظهرت في الوظيفة.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _keywordsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'flutter, react native, remote',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ساعات الهدوء 🌙',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'لا إشعارات بين هذين الوقتين.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickQuietHour(true),
                                icon: const Icon(Icons.nightlight_outlined),
                                label: Text('من: ${_fmtHour(_quietStart)}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickQuietHour(false),
                                icon: const Icon(Icons.wb_sunny_outlined),
                                label: Text('إلى: ${_fmtHour(_quietEnd)}'),
                              ),
                            ),
                          ],
                        ),
                        if (_quietStart >= 0 || _quietEnd >= 0)
                          TextButton(
                            onPressed: () => setState(() {
                              _quietStart = -1;
                              _quietEnd = -1;
                            }),
                            child: const Text('إلغاء ساعات الهدوء'),
                          ),
                      ],
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'ℹ️ الإشعارات تعمل عند فتح التطبيق أو في الخلفية القريبة.',
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

          // — Blocked companies —
          _SectionCard(
            title: 'الشركات المحظورة 🚫',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blocked.isEmpty
                        ? 'لا توجد شركات محظورة.'
                        : 'محظور ${blocked.length} شركة',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (blocked.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in blocked.take(10))
                          Chip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (blocked.length > 10)
                          Chip(label: Text('+${blocked.length - 10}')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _clearBlocked,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('إلغاء حظر الجميع'),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Text(
                      'لحظر شركة: افتح تفاصيل الوظيفة واضغط أيقونة 🚫.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
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

          // — Min budget —
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
                      'التحديث اللحظي مفعّل. GitHub Actions يسحب فرصاً جديدة كل 30 دقيقة من 18 منصة.',
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
              'FreelanceRadar — الإصدار 1.1.0',
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
