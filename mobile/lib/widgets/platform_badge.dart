import 'package:flutter/material.dart';

import '../config/constants.dart';

/// شارة صغيرة تُظهر اسم المنصة بلونها المميز.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key, required this.platform, this.compact = false});

  final String platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color =
        AppConstants.platformColors[platform] ?? Theme.of(context).colorScheme.primary;
    final label = AppConstants.platformLabels[platform] ?? platform;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
