import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Main classification result, confidence indicator, and quality summary.
class ResultCard extends StatelessWidget {
  const ResultCard({required this.prediction, super.key});

  static const lowConfidenceThreshold = 70.0;
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final statusColor = qualityStatusColor(prediction.quality);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Classification result',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.large),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(prediction.fruitTitle, style: AppTextStyles.resultTitle),
                StatusChip(quality: prediction.quality),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'This looks like a ${prediction.qualityTitle.toLowerCase()} '
              '${prediction.fruitTitle.toLowerCase()}.',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.large),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confidence', style: AppTextStyles.body),
                Text(
                  '${prediction.confidence.toStringAsFixed(2)}%',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: (prediction.confidence / 100).clamp(0.0, 1.0),
                minHeight: 12,
                color: statusColor,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            if (prediction.confidence < lowConfidenceThreshold) ...[
              const SizedBox(height: AppSpacing.medium),
              Container(
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.statusOverripe.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF895D00)),
                    SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        'Low confidence - try a clearer photo with a plain background.',
                        style: TextStyle(color: Color(0xFF704B00), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
