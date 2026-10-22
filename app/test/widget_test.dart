import 'dart:ui' show Size;

import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('classifier home page renders', (tester) async {
    await tester.pumpWidget(const FruitQualityApp());
    expect(find.text('Fruit Quality Classifier'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(
      find.text('Point the camera at a fruit and tap Scan fruit'),
      findsOneWidget,
    );
    expect(find.text('Scan fruit'), findsOneWidget);
    expect(find.text('Choose one or more photos'), findsNothing);
    expect(find.text('Classify selected photos'), findsNothing);
    expect(find.textContaining('Quality:'), findsNothing);
    expect(find.textContaining('fresh_'), findsNothing);
    expect(find.textContaining('apple'), findsNothing);
    expect(find.textContaining('orange'), findsNothing);
    expect(find.textContaining('pineapple'), findsNothing);
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
