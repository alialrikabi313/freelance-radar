import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

/// شريط فلاتر ميزانية سريعة: الكل / +500 / +1000 / +2000 / +5000
/// + زر تبديل "شمل بدون سعر" يظهر فقط عند اختيار حد أدنى.
class BudgetFilterChips extends StatelessWidget {
  const BudgetFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.includeUnknownBudget,
    required this.onToggleIncludeUnknown,
  });

  final double selected;
  final ValueChanged<double> onChanged;
  final bool includeUnknownBudget;
  final ValueChanged<bool> onToggleIncludeUnknown;

  @override
  Widget build(BuildContext context) {
    final hasFilter = selected > 0;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount:
            AppConstants.budgetThresholds.length + (hasFilter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          // آخر عنصر عند وجود فلتر: زر "شمل بدون سعر"
          if (hasFilter && i == AppConstants.budgetThresholds.length) {
            return FilterChip(
              label: Text(
                includeUnknownBudget
                    ? 'شاملاً بدون سعر ✓'
                    : 'شمل بدون سعر',
              ),
              selected: includeUnknownBudget,
              onSelected: onToggleIncludeUnknown,
              selectedColor: AppTheme.primary.withOpacity(0.15),
              backgroundColor: const Color(0xFFFEF3C7),
              labelStyle: TextStyle(
                color: includeUnknownBudget
                    ? AppTheme.primary
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: includeUnknownBudget
                      ? AppTheme.primary
                      : const Color(0xFFFBBF24),
                  width: 1.2,
                ),
              ),
              showCheckmark: false,
            );
          }

          final value = AppConstants.budgetThresholds[i];
          final isSelected = value.toDouble() == selected;
          final label = value == 0 ? 'كل الميزانيات' : '+\$$value';

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onChanged(value.toDouble()),
            selectedColor: AppTheme.secondary,
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
