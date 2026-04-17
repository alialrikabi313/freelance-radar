import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

/// شريط فلاتر ميزانية سريعة: الكل / +500 / +1000 / +2000 / +5000
class BudgetFilterChips extends StatelessWidget {
  const BudgetFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppConstants.budgetThresholds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
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
