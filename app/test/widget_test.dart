import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('classifier home page renders', (tester) async {
    await tester.pumpWidget(const FruitQualityApp());
    expect(find.text('Fruit Quality Classifier'), findsOneWidget);
    expect(find.text('Upload fruit image'), findsOneWidget);
  });
}
