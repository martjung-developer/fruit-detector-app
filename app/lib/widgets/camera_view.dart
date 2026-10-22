import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'scan_overlay.dart';

/// Rounded 4:3 live camera preview with the scanning viewfinder overlay.
class CameraView extends StatelessWidget {
  const CameraView({
    required this.controller,
    required this.scanning,
    required this.onPreviewError,
    super.key,
  });

  final CameraController? controller;
  final bool scanning;
  final ValueChanged<CameraException> onPreviewError;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 3,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _previewContent(),
          if (controller != null &&
              controller!.value.isInitialized &&
              !controller!.value.hasError)
            ScanOverlay(scanning: scanning),
          if (controller != null && controller!.value.hasError)
            _PreviewErrorListener(
              errorDescription: controller!.value.errorDescription,
              onPreviewError: onPreviewError,
            ),
        ],
      ),
    ),
  );

  Widget _previewContent() {
    final camera = controller;
    if (camera != null && camera.value.hasError) {
      return const ColoredBox(
        color: AppColors.errorBg,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The camera preview could not start. Check camera access and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.statusRotten),
            ),
          ),
        ),
      );
    }
    if (camera != null && camera.value.isInitialized) {
      // Keep the web HtmlElementView untransformed; camera_web sizes its video
      // element to this clipped 4:3 area with object-fit: cover.
      return CameraPreview(camera);
    }
    return const ColoredBox(
      color: AppColors.primaryDark,
      child: Center(
        child: Icon(Icons.camera_alt_outlined, size: 56, color: Colors.white70),
      ),
    );
  }
}

class _PreviewErrorListener extends StatefulWidget {
  const _PreviewErrorListener({
    required this.errorDescription,
    required this.onPreviewError,
  });

  final String? errorDescription;
  final ValueChanged<CameraException> onPreviewError;

  @override
  State<_PreviewErrorListener> createState() => _PreviewErrorListenerState();
}

class _PreviewErrorListenerState extends State<_PreviewErrorListener> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(_PreviewErrorListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.errorDescription != widget.errorDescription) _report();
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onPreviewError(
          CameraException('preview_error', widget.errorDescription ?? ''),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
