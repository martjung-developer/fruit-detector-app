import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Recoverable upload or API error with an accessible retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.errorBg,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.statusRotten),
              SizedBox(width: AppSpacing.small),
              Text(
                'Could not classify this image',
                style: AppTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Text(message, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.medium),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
