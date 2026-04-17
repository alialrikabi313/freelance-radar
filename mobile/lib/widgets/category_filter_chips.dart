import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

/// شريط فلاتر الفئات: الكل / موبايل / ويب / خادم / ذكاء اصطناعي / ...
class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppConstants.allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = AppConstants.allCategories[i];
          final label = AppConstants.categoryLabels[key] ?? key;
          final icon = AppConstants.categoryIcons[key] ?? Icons.circle;
          final isSelected = key == selected;

          return ChoiceChip(
            avatar: Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onChanged(key),
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
