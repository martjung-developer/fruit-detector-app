import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scan, live-mode, and optional camera-switch controls.
class CameraControls extends StatelessWidget {
  const CameraControls({
    required this.onScan,
    required this.onLiveModeChanged,
    required this.onSwitchCamera,
    required this.canScan,
    required this.isScanning,
    required this.liveMode,
    required this.canSwitchCamera,
    super.key,
  });

  final VoidCallback onScan;
  final ValueChanged<bool> onLiveModeChanged;
  final VoidCallback onSwitchCamera;
  final bool canScan;
  final bool isScanning;
  final bool liveMode;
  final bool canSwitchCamera;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AppSpacing.medium),
      Semantics(
        button: true,
        label: 'Scan fruit with the camera',
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: canScan && !isScanning ? onScan : null,
            icon: const Icon(Icons.photo_camera),
            label: Text(isScanning ? 'Analyzing...' : 'Scan fruit'),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.small),
      Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Live mode',
              child: Tooltip(
                message: 'Automatically scan every two seconds',
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live mode'),
                  value: liveMode,
                  onChanged: canScan ? onLiveModeChanged : null,
                ),
              ),
            ),
          ),
          if (canSwitchCamera)
            Semantics(
              label: 'Switch camera',
              child: IconButton(
                tooltip: 'Switch camera',
                onPressed: isScanning ? null : onSwitchCamera,
                icon: const Icon(Icons.cameraswitch_outlined),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.small),
      const Text(
        'Tip: use good lighting and a plain background.',
        style: TextStyle(fontSize: 13, color: Color(0xFF5E7064)),
      ),
    ],
  );
}
