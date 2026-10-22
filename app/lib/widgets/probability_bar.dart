import 'dart:async';

import 'package:flutter/material.dart';

import '../models/freshness_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One animated freshness probability row with an accessible value label.
class ProbabilityBar extends StatefulWidget {
  const ProbabilityBar({
    required this.freshness,
    required this.value,
    required this.index,
    required this.isTop,
    required this.top,
    super.key,
  });

  final Freshness freshness;
  final double value;
  final int index;
  final bool isTop;
  final Freshness top;

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
        ? widget.top.statusColor
        : AppColors.primary.withValues(alpha: 0.7);
    final percent = widget.value * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Semantics(
        label:
            '${widget.freshness.label}: ${percent.toStringAsFixed(2)} percent',
        child: Row(
          children: [
            SizedBox(
              width: 124,
              child: Text(
                widget.freshness.label,
                maxLines: 1,
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
                        builder: (context, animatedValue, _) => Container(
                          width:
                              constraints.maxWidth *
                              animatedValue.clamp(0.0, 1.0),
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
                '${percent.toStringAsFixed(2)}%',
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
