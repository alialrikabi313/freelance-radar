import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/filter_provider.dart';
import '../providers/jobs_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialFetch());
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
      final filter = context.read<FilterProvider>();
      context.read<JobsProvider>().loadMore(
            platform: filter.selectedPlatform,
            sortBy: filter.sortBy,
            sortOrder: filter.sortOrder,
            language: filter.language,
            minBudget: filter.minBudget,
            search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
          );
    }
  }

  Future<void> _initialFetch() async {
    final filter = context.read<FilterProvider>();
    await context.read<JobsProvider>().fetchJobs(
          platform: filter.selectedPlatform,
          sortBy: filter.sortBy,
          sortOrder: filter.sortOrder,
          language: filter.language,
          minBudget: filter.minBudget,
          search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
        );
  }

  Future<void> _onRefresh() async {
    final filter = context.read<FilterProvider>();
    await context.read<JobsProvider>().refresh(
          platform: filter.selectedPlatform,
          sortBy: filter.sortBy,
          sortOrder: filter.sortOrder,
          language: filter.language,
          minBudget: filter.minBudget,
          search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
        );
    _refreshController.refreshCompleted();
  }

  Future<void> _reloadAfterFilterChange() async {
    _scrollController.jumpTo(0);
    await _initialFetch();
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
                Text(
                  'ترتيب حسب',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
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
                      await _reloadAfterFilterChange();
                    },
                  ),
                const Divider(height: 24),
                SwitchListTile(
                  value: filter.sortOrder == 'desc',
                  onChanged: (_) async {
                    await filter.toggleSortOrder();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    await _reloadAfterFilterChange();
                  },
                  title: const Text('ترتيب تنازلي'),
                  subtitle: Text(
                    filter.sortOrder == 'desc'
                        ? 'من الأعلى إلى الأدنى'
                        : 'من الأدنى إلى الأعلى',
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
          preferredSize: Size.fromHeight(_searchOpen ? 120 : 52),
          child: Column(
            children: [
              if (_searchOpen) _SearchBar(
                controller: _searchController,
                onSubmit: (q) {
                  context.read<FilterProvider>().setSearch(q);
                  _reloadAfterFilterChange();
                },
              ),
              Consumer<FilterProvider>(
                builder: (context, filter, _) => PlatformFilterChips(
                  selected: filter.selectedPlatform,
                  onChanged: (p) {
                    filter.setPlatform(p);
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
              return EmptyState.error(jobs.error!, onRetry: _initialFetch);
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
              itemCount: jobs.jobs.length + (jobs.isLoadingMore ? 1 : 0),
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
