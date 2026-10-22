import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Pulsing placeholder card displayed while the API classifies an image.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonLine(width: 190, height: 22),
                const SizedBox(height: AppSpacing.large),
                _skeletonLine(width: 150, height: 34),
                const SizedBox(height: AppSpacing.medium),
                _skeletonLine(width: double.infinity, height: 14),
                const SizedBox(height: AppSpacing.small),
                _skeletonLine(width: double.infinity, height: 14),
                const SizedBox(height: AppSpacing.large),
                _skeletonLine(width: double.infinity, height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonLine(width: 190, height: 22),
                const SizedBox(height: AppSpacing.medium),
                for (var index = 0; index < 3; index++) ...[
                  _skeletonLine(width: double.infinity, height: 12),
                  const SizedBox(height: AppSpacing.medium),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _skeletonLine({required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
      );
}
