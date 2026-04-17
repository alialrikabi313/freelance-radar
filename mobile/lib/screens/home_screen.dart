import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/filter_provider.dart';
import '../providers/jobs_provider.dart';
import '../widgets/budget_filter_chips.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/job_card.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final jobs = context.read<JobsProvider>();
      if (!jobs.isLoading && jobs.canLoadMore) {
        jobs.loadMore();
      }
    }
  }

  void _subscribe() {
    final filter = context.read<FilterProvider>();
    context.read<JobsProvider>().subscribe(
          platform: filter.selectedPlatform,
          category: filter.selectedCategory,
          sortBy: filter.sortBy,
          sortOrder: filter.sortOrder,
          language: filter.language,
          minBudget: filter.minBudget,
          includeUnknownBudget: filter.includeUnknownBudget,
          search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
        );
  }

  Future<void> _onRefresh() async {
    await context.read<JobsProvider>().refresh();
    _refreshController.refreshCompleted();
  }

  void _reloadAfterFilterChange() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _subscribe();
  }

  Future<void> _showSortSheet() async {
    final filter = context.read<FilterProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ترتيب حسب',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final opt in SortOption.all)
                  RadioListTile<String>(
                    value: opt.value,
                    groupValue: filter.sortBy,
                    title: Text(opt.label),
                    onChanged: (v) async {
                      if (v == null) return;
                      await filter.setSortBy(v);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _reloadAfterFilterChange();
                    },
                  ),
                const Divider(height: 24),
                SwitchListTile(
                  value: filter.sortOrder == 'desc',
                  onChanged: (_) async {
                    await filter.toggleSortOrder();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _reloadAfterFilterChange();
                  },
                  title: const Text('ترتيب تنازلي'),
                  subtitle: Text(
                    filter.sortOrder == 'desc'
                        ? 'من الأعلى إلى الأدنى'
                        : 'من الأدنى إلى الأعلى',
                  ),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  value: filter.includeUnknownBudget,
                  onChanged: (v) {
                    filter.setIncludeUnknownBudget(v);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _reloadAfterFilterChange();
                  },
                  title: const Text('شمل الوظائف بدون ميزانية معلنة'),
                  subtitle: const Text(
                    'مفيد لمستقل وخمسات (لا يعرضان الميزانية في القائمة)',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _AppBarTitle(),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: Icon(_searchOpen ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() => _searchOpen = !_searchOpen);
              if (!_searchOpen) {
                _searchController.clear();
                context.read<FilterProvider>().setSearch('');
                _reloadAfterFilterChange();
              }
            },
          ),
          IconButton(
            tooltip: 'المفضلة',
            icon: const Icon(Icons.favorite_outline),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.favorites),
          ),
          IconButton(
            tooltip: 'ترتيب',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchOpen ? 212 : 140),
          child: Column(
            children: [
              if (_searchOpen)
                _SearchBar(
                  controller: _searchController,
                  onSubmit: (q) {
                    context.read<FilterProvider>().setSearch(q);
                    _reloadAfterFilterChange();
                  },
                ),
              // Platform chips
              Consumer<FilterProvider>(
                builder: (context, filter, _) => PlatformFilterChips(
                  selected: filter.selectedPlatform,
                  onChanged: (p) {
                    filter.setPlatform(p);
                    _reloadAfterFilterChange();
                  },
                ),
              ),
              const SizedBox(height: 4),
              // Category chips
              Consumer<FilterProvider>(
                builder: (context, filter, _) => CategoryFilterChips(
                  selected: filter.selectedCategory,
                  onChanged: (c) {
                    filter.setCategory(c);
                    _reloadAfterFilterChange();
                  },
                ),
              ),
              const SizedBox(height: 4),
              // Budget chips
              Consumer<FilterProvider>(
                builder: (context, filter, _) => BudgetFilterChips(
                  selected: filter.minBudget,
                  onChanged: (v) async {
                    await filter.setMinBudget(v);
                    _reloadAfterFilterChange();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Consumer<JobsProvider>(
        builder: (context, jobs, _) {
          if (jobs.isLoading && jobs.jobs.isEmpty) {
            return const ShimmerList();
          }

          if (!jobs.isLoading && jobs.jobs.isEmpty) {
            if (jobs.error != null) {
              return EmptyState.error(jobs.error!, onRetry: _subscribe);
            }
            return EmptyState.noResults(onRefresh: _onRefresh);
          }

          return SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            header: const WaterDropHeader(
              waterDropColor: AppTheme.primary,
              complete: Text('تم التحديث ✓'),
            ),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: jobs.jobs.length + (jobs.canLoadMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i >= jobs.jobs.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final job = jobs.jobs[i];
                return JobCard(
                  job: job,
                  onFavoriteToggle: () =>
                      context.read<JobsProvider>().toggleFavorite(job),
                  onTap: () {
                    context.read<JobsProvider>().markRead(job.id);
                    Navigator.of(context).pushNamed(
                      AppRoutes.jobDetail,
                      arguments: job,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.radar, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'FreelanceRadar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: 'ابحث في العناوين والأوصاف…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              controller.clear();
              onSubmit('');
            },
          ),
        ),
      ),
    );
  }
}
