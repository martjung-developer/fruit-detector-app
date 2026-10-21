import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() => runApp(const FruitQualityApp());

class FruitQualityApp extends StatelessWidget {
  const FruitQualityApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fruit Quality Classifier',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const HomePage(),
      );
}
