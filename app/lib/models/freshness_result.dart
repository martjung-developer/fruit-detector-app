import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'prediction_result.dart';

/// The three freshness states shown to the user.
enum Freshness {
  fresh,
  overripe,
  rotten;

  /// Display label for this freshness state.
  String get label => switch (this) {
    Freshness.fresh => 'Fresh',
    Freshness.overripe => 'Overripe',
    Freshness.rotten => 'Rotten',
  };

  /// Status color from the app palette.
  Color get statusColor => switch (this) {
    Freshness.fresh => AppColors.statusFresh,
    Freshness.overripe => AppColors.statusOverripe,
    Freshness.rotten => AppColors.statusRotten,
  };

  /// Status icon used by badges and result cards.
  IconData get icon => switch (this) {
    Freshness.fresh => Icons.check_circle,
    Freshness.overripe => Icons.schedule,
    Freshness.rotten => Icons.cancel,
  };

  /// Simple advice for this freshness state.
  String get advice => switch (this) {
    Freshness.fresh => 'Looks good to eat.',
    Freshness.overripe => 'Best eaten soon or used for cooking or smoothies.',
    Freshness.rotten => 'Not safe to eat. Better to throw it away.',
  };
}

/// Probabilities grouped into the freshness-only classes presented by the app.
class FreshnessResult {
  FreshnessResult._(
    Map<Freshness, double> scores, {
    required this.rawTopClass,
    required this.rawConfidence,
    required this.apiLowConfidence,
  }) : probabilities = Map.unmodifiable(_normalize(scores)) {
    final ordered = _sort(probabilities);
    final groupedTop = ordered.first.key;
    final rawQuality = rawTopClass.toLowerCase().split('_').first;
    final rottenProbability = probabilities[Freshness.rotten] ?? 0;
    if (rottenProbability >= 0.25 || rawQuality == 'rotten') {
      top = Freshness.rotten;
    } else if (rawQuality == 'overripe' && groupedTop == Freshness.fresh) {
      top = Freshness.overripe;
    } else {
      top = groupedTop;
    }
    confidence = probabilities[top] ?? 0;
    sortedProbabilities = List.unmodifiable(ordered);
  }

  /// Safety-adjusted freshness state selected for display.
  late final Freshness top;

  /// Probability for [top], normalized to the range from zero to one.
  late final double confidence;

  /// Normalized grouped probabilities for all three freshness states.
  final Map<Freshness, double> probabilities;

  /// All grouped probabilities sorted high to low with stable enum-order ties.
  late final List<MapEntry<Freshness, double>> sortedProbabilities;

  /// Highest individual class label returned by the API.
  final String rawTopClass;

  /// Highest individual class confidence returned by the API, in percent.
  final double rawConfidence;

  /// API confidence flag computed from the raw class prediction.
  final bool apiLowConfidence;

  /// Group raw API classes by the text before the first underscore.
  factory FreshnessResult.fromPrediction(Prediction prediction) {
    final grouped = {for (final state in Freshness.values) state: 0.0};
    for (final entry in prediction.probabilities.entries) {
      final prefix = entry.key.split('_').first.toLowerCase();
      final state = switch (prefix) {
        'fresh' => Freshness.fresh,
        'overripe' => Freshness.overripe,
        'rotten' => Freshness.rotten,
        _ => null,
      };
      if (state != null && entry.value.isFinite && entry.value > 0) {
        grouped[state] = grouped[state]! + entry.value;
      }
    }
    return FreshnessResult._(
      grouped,
      rawTopClass: prediction.label,
      rawConfidence: prediction.confidence,
      apiLowConfidence: prediction.lowConfidence,
    );
  }

  /// Build a result from already-grouped scores, for live-mode smoothing.
  factory FreshnessResult.fromGroupedProbabilities(
    Map<Freshness, double> scores, {
    String rawTopClass = 'unknown',
    double rawConfidence = 0,
    bool apiLowConfidence = false,
  }) => FreshnessResult._(
    {
      for (final state in Freshness.values)
        state:
            scores[state] != null &&
                scores[state]!.isFinite &&
                scores[state]! > 0
            ? scores[state]!
            : 0,
    },
    rawTopClass: rawTopClass,
    rawConfidence: rawConfidence,
    apiLowConfidence: apiLowConfidence,
  );

  static Map<Freshness, double> _normalize(Map<Freshness, double> scores) {
    final sum = Freshness.values.fold<double>(
      0,
      (total, state) => total + (scores[state] ?? 0),
    );
    if (sum == 0) return {for (final state in Freshness.values) state: 0};
    return {
      for (final state in Freshness.values)
        state: sum == 1.0 ? (scores[state] ?? 0) : (scores[state] ?? 0) / sum,
    };
  }

  static List<MapEntry<Freshness, double>> _sort(
    Map<Freshness, double> probabilities,
  ) {
    final entries = [
      for (final state in Freshness.values)
        MapEntry(state, probabilities[state] ?? 0),
    ];
    entries.sort((first, second) {
      final byScore = second.value.compareTo(first.value);
      return byScore != 0
          ? byScore
          : first.key.index.compareTo(second.key.index);
    });
    return entries;
  }
}
