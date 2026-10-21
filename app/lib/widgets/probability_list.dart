import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'probability_bar.dart';

/// Card listing every predicted class from highest to lowest probability.
class ProbabilityList extends StatelessWidget {
  const ProbabilityList({required this.prediction, super.key});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Class probabilities', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.medium),
          for (final entry in prediction.sortedProbabilities.indexed)
            ProbabilityBar(
              key: ValueKey(entry.$2.key),
              label: _humanize(entry.$2.key),
              value: entry.$2.value,
              index: entry.$1,
              isTop: entry.$1 == 0,
              topQuality: prediction.quality,
            ),
        ],
      ),
    ),
  );

  String _humanize(String value) {
    final words = value.replaceAll('_', ' ').split(' ');
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
