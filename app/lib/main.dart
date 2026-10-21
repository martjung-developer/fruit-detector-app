import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const FruitQualityApp());

class FruitQualityApp extends StatelessWidget {
  const FruitQualityApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fruit Quality Classifier',
    theme: AppTheme.data,
    home: const HomePage(),
  );
}
