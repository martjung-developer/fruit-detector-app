import 'dart:typed_data';

import 'package:app/models/freshness_result.dart';
import 'package:app/models/prediction_result.dart';
import 'package:app/models/scan_history.dart';
import 'package:flutter_test/flutter_test.dart';

FreshnessResult _freshResult() => FreshnessResult.fromPrediction(
  const Prediction(
    label: 'fresh_example',
    fruit: '',
    quality: 'fresh',
    confidence: 92,
    probabilities: {'fresh_example': 100},
    lowConfidence: false,
  ),
);

void main() {
  group('ScanHistory', () {
    test('adds entries in scan order', () {
      final history = ScanHistory();
      final entry = history.add(
        imageBytes: Uint8List.fromList([1]),
        result: _freshResult(),
        scannedAt: DateTime(2026, 1, 1, 12),
      );

      expect(history.entries, [entry]);
      expect(history.entries.single.scannedAt.hour, 12);
    });

    test('keeps only the newest twenty entries', () {
      final history = ScanHistory();
      final added = <ScanHistoryEntry>[];
      for (var index = 0; index < 21; index++) {
        added.add(
          history.add(
            imageBytes: Uint8List.fromList([index]),
            result: _freshResult(),
          ),
        );
      }

      expect(history.entries, hasLength(20));
      expect(history.entries.first, same(added[1]));
      expect(history.entries.last, same(added.last));
    });

    test('deletes an entry and undo restores its position', () {
      final history = ScanHistory();
      final entries = [
        for (var index = 0; index < 3; index++)
          history.add(
            imageBytes: Uint8List.fromList([index]),
            result: _freshResult(),
          ),
      ];

      final deleted = history.delete(entries[1]);
      expect(deleted, isNotNull);
      expect(history.entries, [entries[0], entries[2]]);
      history.undo(deleted!);
      expect(history.entries, entries);
      expect(history.delete(entries[1]), isNotNull);
    });

    test('clear removes every entry', () {
      final history = ScanHistory();
      history.add(imageBytes: Uint8List(1), result: _freshResult());
      history.add(imageBytes: Uint8List(1), result: _freshResult());

      history.clear();

      expect(history.entries, isEmpty);
    });
  });
}
