import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Return the visual status color associated with a quality label.
Color qualityStatusColor(String quality) => switch (quality.toLowerCase()) {
  'fresh' => AppColors.statusFresh,
  'overripe' => AppColors.statusOverripe,
  'rotten' => AppColors.statusRotten,
  _ => AppColors.primary,
};

/// Compact, accessible badge for the predicted quality state.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.quality, super.key});

  final String quality;

  @override
  Widget build(BuildContext context) {
    final color = qualityStatusColor(quality);
    final icon = switch (quality.toLowerCase()) {
      'fresh' => Icons.check_circle,
      'overripe' => Icons.schedule,
      'rotten' => Icons.cancel,
      _ => Icons.info,
    };
    return Semantics(
      label: 'Quality status: ${quality.toLowerCase()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              quality[0].toUpperCase() + quality.substring(1).toLowerCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
