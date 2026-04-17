import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

/// شريط شيبات لاختيار المنصة (الكل / Upwork / Freelancer / مستقل / خمسات).
class PlatformFilterChips extends StatelessWidget {
  const PlatformFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <String>['all', ...AppConstants.allPlatforms];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = options[i];
          final label = AppConstants.platformLabels[key] ?? key;
          final isSelected = key == selected;
          final platformColor = AppConstants.platformColors[key];

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onChanged(key),
            selectedColor: platformColor ?? AppTheme.primary,
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
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
