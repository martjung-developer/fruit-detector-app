import 'package:flutter/material.dart';

import '../models/scan_history.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Compact, bounded history of manual scans with delete actions.
class ScanHistoryList extends StatelessWidget {
  const ScanHistoryList({
    required this.entries,
    required this.onSelect,
    required this.onDelete,
    required this.onClearAll,
    super.key,
  });

  final List<ScanHistoryEntry> entries;
  final ValueChanged<ScanHistoryEntry> onSelect;
  final ValueChanged<ScanHistoryEntry> onDelete;
  final VoidCallback onClearAll;

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Scan history', style: AppTextStyles.sectionTitle),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear all'),
                ),
            ],
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
              child: Text('No scans yet', style: AppTextStyles.caption),
            )
          else
            for (final entry in entries.reversed)
              InkWell(
                onTap: () => onSelect(entry),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          entry.imageBytes,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusChip(freshness: entry.result.top),
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${(entry.result.confidence * 100).toStringAsFixed(2)}%',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              _timeLabel(entry.scannedAt),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete scan',
                        onPressed: () => onDelete(entry),
                        icon: const Icon(Icons.delete_outline),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
