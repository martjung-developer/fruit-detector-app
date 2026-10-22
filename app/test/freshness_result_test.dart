import 'package:app/models/freshness_result.dart';
import 'package:app/models/prediction_result.dart';
import 'package:flutter_test/flutter_test.dart';

Prediction prediction(Map<String, double> probabilities) => Prediction(
  label: probabilities.keys.first,
  fruit: '',
  quality: '',
  confidence: 0,
  probabilities: probabilities,
  lowConfidence: false,
);

void main() {
  group('FreshnessResult', () {
    test('groups the nine-class response into three freshness states', () {
      final result = FreshnessResult.fromPrediction(
        prediction({
          'fresh_apple': 15,
          'fresh_orange': 20,
          'fresh_pineapple': 15,
          'overripe_apple': 10,
          'overripe_orange': 10,
          'overripe_pineapple': 10,
          'rotten_apple': 5,
          'rotten_orange': 5,
          'rotten_pineapple': 10,
        }),
      );

      expect(result.top, Freshness.fresh);
      expect(result.confidence, 0.5);
      expect(result.probabilities.length, 3);
      expect(result.probabilities[Freshness.overripe], 0.3);
      expect(result.probabilities[Freshness.rotten], 0.2);
    });

    test('accepts a three-class response', () {
      final result = FreshnessResult.fromPrediction(
        prediction({'fresh': 0.1, 'overripe': 0.7, 'rotten': 0.2}),
      );

      expect(result.top, Freshness.overripe);
      expect(result.confidence, 0.7);
      expect(result.sortedProbabilities.map((entry) => entry.key), [
        Freshness.overripe,
        Freshness.rotten,
        Freshness.fresh,
      ]);
    });

    test('normalizes grouped scores when they do not sum to one', () {
      final result = FreshnessResult.fromPrediction(
        prediction({'fresh': 20, 'overripe': 30}),
      );

      expect(result.probabilities[Freshness.fresh], closeTo(0.4, 1e-12));
      expect(result.probabilities[Freshness.overripe], closeTo(0.6, 1e-12));
      expect(result.probabilities.values.reduce((a, b) => a + b), 1.0);
    });

    test('ignores unknown classes and handles an unknown-only response', () {
      final mixed = FreshnessResult.fromPrediction(
        prediction({'unripe_example': 0.9, 'rotten': 0.1}),
      );
      expect(mixed.top, Freshness.rotten);
      expect(mixed.confidence, 1.0);

      final unknownOnly = FreshnessResult.fromPrediction(
        prediction({'unknown': 1.0}),
      );
      expect(unknownOnly.probabilities.length, 3);
      expect(unknownOnly.confidence, 0);
    });

    test('resolves ties in enum order', () {
      final result = FreshnessResult.fromPrediction(
        prediction({'rotten': 1, 'overripe': 1, 'fresh': 1}),
      );

      expect(result.top, Freshness.fresh);
      expect(result.sortedProbabilities.map((entry) => entry.key), [
        Freshness.fresh,
        Freshness.overripe,
        Freshness.rotten,
      ]);
    });
  });
}
