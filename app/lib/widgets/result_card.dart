import 'package:flutter/material.dart';

import '../models/freshness_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Freshness-only result, confidence, advice, and raw API details.
class ResultCard extends StatelessWidget {
  const ResultCard({required this.result, required this.liveMode, super.key});

  static const double lowConfidenceThreshold = 0.70;

  final FreshnessResult result;
  final bool liveMode;

  @override
  Widget build(BuildContext context) {
    final uncertain =
        result.confidence < lowConfidenceThreshold || result.apiLowConfidence;
    final amber = AppColors.statusOverripe;
    const amberText = Color(0xFF704B00);

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
                Text(
                  uncertain ? 'Uncertain' : result.top.label,
                  style: AppTextStyles.resultTitle,
                ),
                if (uncertain)
                  Semantics(
                    label: 'Freshness result uncertain',
                    child: Chip(
                      avatar: Icon(Icons.help_outline, color: amber),
                      label: Text(
                        'Uncertain',
                        style: TextStyle(
                          color: amberText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: const Color(0xFFFFF4D9),
                      side: BorderSide.none,
                    ),
                  )
                else
                  StatusChip(freshness: result.top),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            if (uncertain)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: amber.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Result uncertain. Retake the photo and do not rely on this to judge food safety.',
                  style: TextStyle(color: amberText, height: 1.4),
                ),
              )
            else ...[
              Text(
                'This fruit looks ${result.top.label.toLowerCase()}.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(result.top.advice, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.large),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confidence', style: AppTextStyles.body),
                Text(
                  '${(result.confidence * 100).toStringAsFixed(2)}%',
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
                value: result.confidence.clamp(0.0, 1.0),
                minHeight: 12,
                color: uncertain ? amber : result.top.statusColor,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            const Divider(),
            const SizedBox(height: AppSpacing.small),
            const Text('Details', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.small),
            _DetailRow(label: 'API top class', value: result.rawTopClass),
            _DetailRow(
              label: 'API confidence',
              value: '${result.rawConfidence.toStringAsFixed(2)}%',
            ),
            if (liveMode) ...[
              const SizedBox(height: AppSpacing.medium),
              const Text(
                'Live mode: updating every 2 seconds',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 112, child: Text(label, style: AppTextStyles.caption)),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
