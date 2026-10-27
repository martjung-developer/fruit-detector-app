import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Viewfinder corner brackets and a readable camera hint pill.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({required this.scanning, super.key});

  final bool scanning;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanning && !oldWidget.scanning) {
      _pulse.repeat(reverse: true);
    } else if (!widget.scanning && oldWidget.scanning) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: widget.scanning
                    ? Border.all(
                        color: AppColors.statusFresh.withValues(
                          alpha: 0.45 + _pulse.value * 0.5,
                        ),
                        width: 3,
                      )
                    : null,
                boxShadow: widget.scanning
                    ? [
                        BoxShadow(
                          color: AppColors.statusFresh.withValues(
                            alpha: 0.12 + _pulse.value * 0.15,
                          ),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: CustomPaint(painter: const _CornerBracketPainter()),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                widget.scanning
                    ? 'Analyzing...'
                    : 'Place one fruit inside the square',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.0;
    const length = 26.0;
    final points = <List<Offset>>[
      [
        const Offset(inset, length),
        const Offset(inset, inset),
        const Offset(length, inset),
      ],
      [
        Offset(size.width - length, inset),
        Offset(size.width - inset, inset),
        Offset(size.width - inset, length),
      ],
      [
        Offset(inset, size.height - length),
        Offset(inset, size.height - inset),
        Offset(length, size.height - inset),
      ],
      [
        Offset(size.width - length, size.height - inset),
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - length),
      ],
    ];
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final bracketPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final corner in points) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) => false;
}
