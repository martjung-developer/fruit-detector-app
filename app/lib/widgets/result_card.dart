import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/freshness_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Freshness-only result, confidence, advice, and frozen scan preview.
class ResultCard extends StatelessWidget {
  const ResultCard({
    required this.result,
    required this.liveMode,
    required this.onScanAgain,
    this.frameBytes,
    super.key,
  });

  static const double lowConfidenceThreshold = 0.70;

  final FreshnessResult result;
  final Uint8List? frameBytes;
  final bool liveMode;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Freshness result', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.large),
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(result.top.label, style: AppTextStyles.resultTitle),
              StatusChip(freshness: result.top),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'This fruit looks ${result.top.label.toLowerCase()}.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(result.top.advice, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.large),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Confidence', style: AppTextStyles.body),
              Text(
                '${(result.confidence * 100).toStringAsFixed(2)}%',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: result.confidence.clamp(0.0, 1.0),
              minHeight: 12,
              color: result.top.statusColor,
              backgroundColor: AppColors.primarySoft,
            ),
          ),
          if (result.confidence < lowConfidenceThreshold) ...[
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
                      'Low confidence - move closer, use better lighting, or try a plain background.',
                      style: TextStyle(color: Color(0xFF704B00), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (liveMode) ...[
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'Live mode: updating every 2 seconds',
              style: AppTextStyles.caption,
            ),
          ],
          if (frameBytes != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    frameBytes!,
                    width: 96,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Text('Captured frame', style: AppTextStyles.caption),
                ),
                TextButton.icon(
                  onPressed: onScanAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan again'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
