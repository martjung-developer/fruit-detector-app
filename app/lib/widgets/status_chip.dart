import 'package:flutter/material.dart';

import '../models/freshness_result.dart';

/// Accessible colored badge for one freshness state.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.freshness, super.key});

  final Freshness freshness;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Freshness: ${freshness.label}',
    child: Tooltip(
      message: freshness.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: freshness.statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(freshness.icon, size: 18, color: freshness.statusColor),
            const SizedBox(width: 8),
            Text(
              freshness.label,
              style: TextStyle(
                color: freshness.statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
