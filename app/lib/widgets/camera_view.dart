import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'scan_overlay.dart';

/// Rounded 4:3 live camera preview with the scanning viewfinder overlay.
class CameraView extends StatelessWidget {
  const CameraView({
    required this.controller,
    required this.scanning,
    this.fallbackFrame,
    super.key,
  });

  final CameraController? controller;
  final bool scanning;
  final Uint8List? fallbackFrame;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 3,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _previewContent(),
          if (controller != null && controller!.value.isInitialized)
            ScanOverlay(scanning: scanning),
        ],
      ),
    ),
  );

  Widget _previewContent() {
    final camera = controller;
    if (camera != null && camera.value.isInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final aspectRatio = camera.value.aspectRatio;
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / aspectRatio,
              child: CameraPreview(camera),
            ),
          );
        },
      );
    }
    if (fallbackFrame case final bytes?) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return const ColoredBox(
      color: AppColors.primaryDark,
      child: Center(
        child: Icon(Icons.camera_alt_outlined, size: 56, color: Colors.white70),
      ),
    );
  }
}
