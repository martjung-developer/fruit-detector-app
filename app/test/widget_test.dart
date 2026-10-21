import 'dart:ui' show Size;

import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('classifier home page renders', (tester) async {
    await tester.pumpWidget(const FruitQualityApp());
    expect(find.text('Fruit Quality Classifier'), findsOneWidget);
    expect(find.text('Click to upload a fruit image'), findsOneWidget);
    expect(find.text('Your result will appear here'), findsOneWidget);
  });

  testWidgets('home page fits phone, tablet, and desktop widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [360.0, 600.0, 899.0, 900.0, 1100.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const FruitQualityApp());
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Layout overflow at $width px',
      );
    }
  });
}
