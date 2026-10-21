import 'package:flutter/material.dart';

class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({required this.label, required this.value, super.key});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(label)),
            Expanded(
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
            SizedBox(width: 56, child: Text('  ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%')),
          ],
        ),
      );
}
