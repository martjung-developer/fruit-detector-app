import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Friendly prompt shown until the first image has been classified.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.extraLarge),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.eco, size: 64, color: AppColors.primarySoft),
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'Your result will appear here',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'Choose a clear photo of an apple, orange, or pineapple to get started.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
