import 'package:flutter/material.dart';

import '../models/freshness_result.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'probability_bar.dart';

/// Card listing the three freshness scores from highest to lowest.
class ProbabilityList extends StatelessWidget {
  const ProbabilityList({required this.result, super.key});

  final FreshnessResult result;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Freshness probabilities',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.medium),
          for (final entry in result.sortedProbabilities.indexed)
            ProbabilityBar(
              key: ValueKey(entry.$2.key),
              freshness: entry.$2.key,
              value: entry.$2.value,
              index: entry.$1,
              isTop: entry.$1 == 0,
              top: result.top,
            ),
        ],
      ),
    ),
  );
}
