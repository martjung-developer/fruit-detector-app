import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'photo_fallback_button.dart';

/// Friendly camera permission and availability guidance with retry/fallback.
class CameraErrorState extends StatelessWidget {
  const CameraErrorState({
    required this.problem,
    required this.onRetry,
    required this.onUsePhoto,
    super.key,
  });

  final CameraProblem problem;
  final VoidCallback onRetry;
  final VoidCallback onUsePhoto;

  String get _message => switch (problem) {
    CameraProblem.permissionDenied => 'Camera access is blocked. Allow camera permission in your browser or device settings, then tap Try again.',
    CameraProblem.noCameraFound => 'No camera was found on this device.',
    CameraProblem.cameraBusy =>
      'The camera is being used by another app. Close it and try again.',
    CameraProblem.unknown =>
      'The camera could not be started. Check its permissions and try again.',
  };

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.medium),
          const Text('Camera unavailable', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.small),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
          PhotoFallbackButton(onPressed: onUsePhoto),
        ],
      ),
    ),
  );
}
