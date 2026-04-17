import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'firebase_options.dart';
import 'providers/filter_provider.dart';
import 'providers/jobs_provider.dart';
import 'services/cache_service.dart';
import 'services/firestore_service.dart';
import 'services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('ar', null);
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setDefaultLocale('ar');

  final cache = CacheService();
  await cache.init();

  final firestore = FirestoreService();
  final notifications = NotificationsService(firestore, cache);
  await notifications.init();
  // ابدأ المراقبة تلقائياً لو المستخدم فعّل الإشعارات سابقاً
  await notifications.start();

  runApp(
    MultiProvider(
      providers: [
        Provider<CacheService>.value(value: cache),
        Provider<FirestoreService>.value(value: firestore),
        Provider<NotificationsService>.value(value: notifications),
        ChangeNotifierProvider(create: (_) => FilterProvider(cache)),
        ChangeNotifierProvider(
          create: (_) => JobsProvider(firestore, cache),
        ),
      ],
      child: const FreelanceRadarApp(),
    ),
  );
}
