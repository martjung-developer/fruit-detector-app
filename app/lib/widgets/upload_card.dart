import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Image picker drop zone and selected-image preview.
class UploadCard extends StatefulWidget {
  const UploadCard({
    required this.onPick,
    required this.loading,
    this.imageBytes,
    super.key,
  });

  final VoidCallback onPick;
  final bool loading;
  final Uint8List? imageBytes;

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your fruit photo', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.medium),
          if (widget.imageBytes case final bytes?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.loading ? null : widget.onPick,
                icon: const Icon(Icons.refresh),
                label: const Text('Choose another image'),
              ),
            ),
          ] else ...[
            MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Semantics(
                button: true,
                label: 'Click to upload a fruit image. JPG or PNG.',
                child: GestureDetector(
                  onTap: widget.loading ? null : widget.onPick,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    height: 230,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? AppColors.primarySoft
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(
                      painter: _DashedBorderPainter(
                        color: _hovered ? AppColors.primary : AppColors.border,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: _hovered
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(height: AppSpacing.medium),
                              const Text(
                                'Click to upload a fruit image',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body,
                              ),
                              const SizedBox(height: AppSpacing.small),
                              const Text(
                                'JPG or PNG',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (widget.loading) ...[
            const SizedBox(height: AppSpacing.medium),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(16);
    const dashLength = 8.0;
    const gapLength = 6.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength)
            .clamp(0.0, metric.length)
            .toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
