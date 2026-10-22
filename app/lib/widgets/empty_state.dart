import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Camera-focused prompt shown before the first scan.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.extraLarge),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: AppColors.primarySoft,
            ),
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'Point the camera at a fruit and tap Scan fruit',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'Good lighting and a plain background help provide a clearer freshness estimate.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
