import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/scan_controller.dart';
import '../models/scan_history.dart';
import '../services/camera_service.dart';
import '../theme/app_text_styles.dart';
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
import '../widgets/scan_history_list.dart';

/// Responsive camera scanning page and saved scan history.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  static const collectMode = bool.fromEnvironment(
    'COLLECT',
    defaultValue: false,
  );

  /// Optional controller override for widget tests.
  final ScanController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _collectionLabels = <String>[
    'fresh_apple',
    'fresh_orange',
    'fresh_pineapple',
    'overripe_apple',
    'overripe_orange',
    'overripe_pineapple',
    'rotten_apple',
    'rotten_orange',
    'rotten_pineapple',
  ];

  late final ScanController _controller;
  late final bool _ownsController;
  final TextEditingController _sourceIdController = TextEditingController(
    text: 'source-001',
  );
  String _collectionLabel = _collectionLabels.first;
  int _sourceSuggestion = 1;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ScanController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _sourceIdController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _retryScan() {
    if (_controller.cameraController?.value.isInitialized ?? false) {
      unawaited(_controller.scan());
    } else {
      unawaited(_controller.usePhotoInstead());
    }
  }

  Future<void> _confirmClearHistory() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text('This will remove all saved scans.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) _controller.clearHistory();
  }

  void _deleteHistoryEntry(ScanHistoryEntry entry) {
    final deleted = _controller.deleteHistoryEntry(entry);
    if (deleted == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _controller.undoDelete(deleted),
        ),
      ),
    );
  }

  Widget _cameraCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camera', style: AppTextStyles.sectionTitle),
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
              onPreviewError: (_) =>
                  _controller.reportPreviewError(CameraProblem.unknown),
            ),
            CameraControls(
              onScan: () => unawaited(_controller.scan()),
              onLiveModeChanged: _controller.setLiveMode,
              onSwitchCamera: () => unawaited(_controller.switchCamera()),
              canScan:
                  _controller.cameraController?.value.isInitialized ?? false,
              isScanning: _controller.isScanning,
              hasManualScan: _controller.hasManualScan,
              liveMode: _controller.liveMode,
              canSwitchCamera: _controller.canSwitchCamera,
            ),
            if (HomePage.collectMode) ...[
              const SizedBox(height: AppSpacing.medium),
              _collectionCard(),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _cameraColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cameraCard(),
      const SizedBox(height: AppSpacing.large),
      ScanHistoryList(
        entries: _controller.history,
        onSelect: _controller.selectHistoryEntry,
        onDelete: _deleteHistoryEntry,
        onClearAll: () => unawaited(_confirmClearHistory()),
      ),
    ],
  );

  Widget _resultArea() {
    switch (_controller.state) {
      case ScanState.scanning:
        return const LoadingSkeleton(key: ValueKey('scanning'));
      case ScanState.apiError:
        return ErrorState(
          key: const ValueKey('api-error'),
          message: 'Could not reach the classification server. Make sure the API is running.',
          onRetry: _retryScan,
        );
      case ScanState.initializingCamera:
      case ScanState.cameraProblem:
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
        ResultCard(result: result, liveMode: _controller.liveMode),
        const SizedBox(height: AppSpacing.medium),
        ProbabilityList(result: result),
      ],
    );
  }

  Widget _collectionCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Collect screen data', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.small),
          DropdownButtonFormField<String>(
            initialValue: _collectionLabel,
            decoration: const InputDecoration(labelText: 'True label'),
            items: _collectionLabels
                .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)),
                )
                .toList(),
            onChanged: _controller.isCollecting
                ? null
                : (label) {
                    if (label != null) setState(() => _collectionLabel = label);
                  },
          ),
          TextField(
            controller: _sourceIdController,
            enabled: !_controller.isCollecting,
            decoration: const InputDecoration(
              labelText: 'Source ID',
              helperText:
                  'Use one ID for five frames of the same website image.',
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton.icon(
            onPressed:
                _controller.isCollecting ||
                    _controller.liveMode ||
                    !(_controller.cameraController?.value.isInitialized ??
                        false)
                ? null
                : () async {
                    final sourceId = _sourceIdController.text.trim();
                    await _controller.collectFive(
                      label: _collectionLabel,
                      sourceId: sourceId,
                    );
                    if (!mounted) return;
                    if (_controller.collectionMessage?.startsWith(
                          'Saved 5 of 5',
                        ) ??
                        false) {
                      _sourceSuggestion++;
                      _sourceIdController.text =
                          'source-${_sourceSuggestion.toString().padLeft(3, '0')}';
                    }
                    setState(() {});
                  },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _controller.isCollecting ? 'Capturing...' : 'Capture x5',
            ),
          ),
          Text(
            'Captured for this class: ${_controller.collectionCount(_collectionLabel)}',
          ),
          if (_controller.collectionMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Text(message),
            ),
        ],
      ),
    ),
  );

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
                            Expanded(child: _cameraColumn()),
                            const SizedBox(width: AppSpacing.large),
                            Expanded(child: _animatedResults()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _cameraColumn(),
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
