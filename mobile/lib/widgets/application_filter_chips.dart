import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

/// شريط فلترة حسب حالة التقديم.
class ApplicationFilterChips extends StatelessWidget {
  const ApplicationFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = <Map<String, dynamic>>[
    {'value': AppConstants.appFilterAll, 'label': 'الكل', 'icon': Icons.list},
    {
      'value': AppConstants.appFilterNotReviewed,
      'label': 'جديدة',
      'icon': Icons.fiber_new_outlined,
    },
    {
      'value': AppConstants.appFilterOnlyInterested,
      'label': 'مهتم',
      'icon': Icons.visibility_outlined,
    },
    {
      'value': AppConstants.appFilterOnlyApplied,
      'label': 'قدّمت',
      'icon': Icons.check_circle_outline,
    },
    {
      'value': AppConstants.appFilterHideApplied,
      'label': 'إخفاء المكرّرة',
      'icon': Icons.hide_source,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _options[i];
          final value = opt['value'] as String;
          final isSelected = value == selected;
          return ChoiceChip(
            avatar: Icon(
              opt['icon'] as IconData,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            label: Text(opt['label'] as String),
            selected: isSelected,
            onSelected: (_) => onChanged(value),
            selectedColor: AppTheme.primary,
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
