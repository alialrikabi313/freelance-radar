import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/job_model.dart';
import 'cache_service.dart';
import 'firestore_service.dart';

/// يدير الإشعارات المحلية للوظائف الجديدة عالية الميزانية.
///
/// كيف يعمل:
///   1. يستمع لـ Firestore stream للوظائف الجديدة (بعد آخر وقت فحص).
///   2. يفلتر محلياً حسب الـ budget threshold الذي يحدده المستخدم.
///   3. يُظهر إشعاراً محلياً لكل وظيفة جديدة متطابقة.
///
/// ملاحظة: الإشعارات تعمل فقط حين التطبيق مفتوح أو في الخلفية القريبة.
/// للإشعارات عند إغلاق التطبيق كلياً، يحتاج FCM (مدفوع حالياً).
class NotificationsService {
  NotificationsService(this._firestore, this._cache);

  final FirestoreService _firestore;
  final CacheService _cache;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<List<Job>>? _sub;
  bool _initialized = false;
  int _notificationId = 0;

  static const String _channelId = 'freelance_radar_jobs';
  static const String _channelName = 'فرص عمل جديدة';
  static const String _channelDescription =
      'إشعار عند ظهور فرصة جديدة تطابق معاييرك';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings);

    // إنشاء قناة Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  /// طلب إذن الإشعارات من المستخدم (يُستدعى مرة واحدة).
  Future<bool> requestPermission() async {
    await init();
    // Android 13+ يحتاج إذن صريح
    final status = await Permission.notification.request();
    if (!status.isGranted) return false;

    // iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  /// ابدأ مراقبة الوظائف الجديدة.
  ///
  /// يُستدعى عند تشغيل التطبيق (إذا كانت الإشعارات مفعّلة) وبعد تغيير
  /// الإعدادات.
  Future<void> start() async {
    if (!_cache.notificationsEnabled) {
      await stop();
      return;
    }
    await init();
    await _sub?.cancel();

    final threshold = _cache.notificationBudgetThreshold;
    final includeUnknown = _cache.notificationIncludeUnknownBudget;
    final lastChecked = _cache.lastNotifiedAt;

    _sub = _firestore
        .watchNewHighBudgetJobs(
      after: lastChecked,
      minBudget: threshold,
      includeUnknownBudget: includeUnknown,
    )
        .listen((newJobs) async {
      if (newJobs.isEmpty) return;

      final latest = newJobs
          .map((j) => j.scrapedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // ساعات الهدوء — تخطّ الإشعارات لكن حدّث الوقت
      if (_cache.isInQuietHours) {
        await _cache.setLastNotifiedAt(latest);
        return;
      }

      // فلتر keyword alerts إن وُجدت
      final keywords = _cache.keywordAlerts
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toList();

      for (final job in newJobs) {
        if (keywords.isNotEmpty) {
          final haystack =
              '${job.title} ${job.description} ${job.skills.join(" ")}'
                  .toLowerCase();
          if (!keywords.any((k) => haystack.contains(k))) continue;
        }
        await _showJobNotification(job);
      }
      await _cache.setLastNotifiedAt(latest);
    }, onError: (err) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationsService error: $err');
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _showJobNotification(Job job) async {
    final budgetText = job.budgetText == '—'
        ? 'ميزانية غير معلنة'
        : job.budgetText;
    final body = '$budgetText • ${job.platform.toUpperCase()}';

    await _plugin.show(
      _notificationId++,
      job.title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: job.url,
    );
  }
}
