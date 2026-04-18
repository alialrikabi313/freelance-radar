import 'package:flutter/material.dart';

import '../models/job_model.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/job_detail_screen.dart';
import '../screens/preview_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String jobDetail = '/job';
  static const String settings = '/settings';
  static const String favorites = '/favorites';
  static const String stats = '/stats';
  static const String preview = '/preview';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case favorites:
        return MaterialPageRoute(builder: (_) => const FavoritesScreen());
      case stats:
        return MaterialPageRoute(builder: (_) => const StatsScreen());
      case preview:
        final args = routeSettings.arguments as Map<String, String>;
        return MaterialPageRoute(
          builder: (_) => PreviewScreen(
            url: args['url'] ?? '',
            title: args['title'] ?? '',
          ),
        );
      case jobDetail:
        final job = routeSettings.arguments as Job;
        return MaterialPageRoute(
          builder: (_) => JobDetailScreen(job: job),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('صفحة غير موجودة')),
          ),
        );
    }
  }
}
