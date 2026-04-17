import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton للتحميل يُشبه شكل Job Card الفعلي.
class JobCardShimmer extends StatelessWidget {
  const JobCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF475569)
        : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlight,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: baseColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _bar(width: 70, height: 20, color: baseColor),
                const Spacer(),
                _bar(width: 80, height: 20, color: baseColor),
              ],
            ),
            const SizedBox(height: 14),
            _bar(width: double.infinity, height: 14, color: baseColor),
            const SizedBox(height: 8),
            _bar(width: 200, height: 14, color: baseColor),
            const SizedBox(height: 14),
            Row(
              children: [
                _bar(width: 60, height: 22, color: baseColor),
                const SizedBox(width: 8),
                _bar(width: 70, height: 22, color: baseColor),
                const SizedBox(width: 8),
                _bar(width: 50, height: 22, color: baseColor),
              ],
            ),
            const SizedBox(height: 14),
            _bar(width: 150, height: 12, color: baseColor),
          ],
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height, required Color color}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const JobCardShimmer(),
    );
  }
}
