import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../models/job_model.dart';
import '../providers/jobs_provider.dart';
import '../services/cache_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/job_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final cache = context.read<CacheService>();
    _future = cache.getAllFavoriteJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: FutureBuilder<List<Job>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final favs = snap.data ?? const <Job>[];
          if (favs.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_outline,
              title: 'لا توجد مفضّلات بعد',
              subtitle: 'اضغط على ♡ في أي فرصة لإضافتها هنا.',
            );
          }
          // ترتيب بالأحدث نشراً
          favs.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: favs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final job = favs[i];
              return JobCard(
                job: job,
                onFavoriteToggle: () async {
                  await context.read<JobsProvider>().toggleFavorite(job);
                  setState(_load);
                },
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.jobDetail,
                  arguments: job,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
