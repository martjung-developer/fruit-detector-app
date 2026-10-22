import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/scan_controller.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_header.dart';
import '../widgets/camera_controls.dart';
import '../widgets/camera_error_state.dart';
import '../widgets/camera_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/probability_list.dart';
import '../widgets/result_card.dart';

/// Responsive camera page that listens to [ScanController].
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  /// Optional controller override for widget tests.
  final ScanController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScanController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ScanController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _scanAgain() {
    if (_controller.cameraController?.value.isInitialized ?? false) {
      unawaited(_controller.scan());
    } else {
      unawaited(_controller.usePhotoInstead());
    }
  }

  Widget _cameraCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camera',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.medium),
          if (_controller.cameraProblem != null)
            CameraErrorState(
              problem: _controller.cameraProblem!,
              onRetry: () => unawaited(_controller.retryCamera()),
              onUsePhoto: () => unawaited(_controller.usePhotoInstead()),
            )
          else ...[
            CameraView(
              controller: _controller.cameraController,
              scanning: _controller.isScanning,
              fallbackFrame: _controller.cameraController == null
                  ? _controller.capturedFrame
                  : null,
            ),
            CameraControls(
              onScan: () => unawaited(_controller.scan()),
              onLiveModeChanged: _controller.setLiveMode,
              onSwitchCamera: () => unawaited(_controller.switchCamera()),
              canScan:
                  _controller.cameraController?.value.isInitialized ?? false,
              isScanning: _controller.isScanning,
              liveMode: _controller.liveMode,
              canSwitchCamera: _controller.canSwitchCamera,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _resultArea() {
    switch (_controller.state) {
      case ScanState.initializingCamera:
        if (_controller.result == null) return const EmptyState();
        break;
      case ScanState.scanning:
        return const LoadingSkeleton(key: ValueKey('scanning'));
      case ScanState.apiError:
        return ErrorState(
          key: const ValueKey('api-error'),
          message: 'Could not reach the classification server. Make sure the API is running.',
          onRetry: _scanAgain,
        );
      case ScanState.cameraProblem:
        if (_controller.result == null) return const EmptyState();
        break;
      case ScanState.ready:
        if (_controller.result == null) return const EmptyState();
        break;
      case ScanState.result:
        break;
    }
    final result = _controller.result;
    if (result == null) return const EmptyState();
    return Column(
      key: ValueKey('result-${result.top.name}-${_controller.liveMode}'),
      children: [
        ResultCard(
          result: result,
          frameBytes: _controller.capturedFrame,
          liveMode: _controller.liveMode,
          onScanAgain: _scanAgain,
        ),
        const SizedBox(height: AppSpacing.medium),
        ProbabilityList(result: result),
      ],
    );
  }

  Widget _animatedResults() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 450),
    switchInCurve: Curves.easeOutCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: _resultArea(),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) => Scaffold(
      appBar: const AppHeader(),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = Responsive.isDesktop(constraints.maxWidth);
            final padding = Responsive.isMobile(constraints.maxWidth)
                ? AppSpacing.medium
                : AppSpacing.large;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding,
                AppSpacing.large,
                padding,
                AppSpacing.extraLarge,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _cameraCard()),
                            const SizedBox(width: AppSpacing.large),
                            Expanded(child: _animatedResults()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _cameraCard(),
                            const SizedBox(height: AppSpacing.large),
                            _animatedResults(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
