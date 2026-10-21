import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// One staggered, animated class probability row.
class ProbabilityBar extends StatefulWidget {
  const ProbabilityBar({
    required this.label,
    required this.value,
    required this.index,
    required this.isTop,
    required this.topQuality,
    super.key,
  });

  final String label;
  final double value;
  final int index;
  final bool isTop;
  final String topQuality;

  @override
  State<ProbabilityBar> createState() => _ProbabilityBarState();
}

class _ProbabilityBarState extends State<ProbabilityBar> {
  Timer? _staggerTimer;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _staggerTimer = Timer(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.isTop
        ? qualityStatusColor(widget.topQuality)
        : AppColors.primary.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        label: '${widget.label}: ${widget.value.toStringAsFixed(2)} percent',
        child: Row(
          children: [
            SizedBox(
              width: 124,
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(height: 12, color: AppColors.primarySoft),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: _animate ? widget.value : 0,
                        ),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedValue, child) => Container(
                          width:
                              constraints.maxWidth *
                              (animatedValue / 100).clamp(0, 1),
                          height: 12,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            SizedBox(
              width: 58,
              child: Text(
                '${widget.value.toStringAsFixed(2)}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
