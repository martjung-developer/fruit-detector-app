import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models/freshness_result.dart';
import '../services/camera_service.dart';

/// The visible state of the camera scan flow.
enum ScanState {
  initializingCamera,
  ready,
  scanning,
  result,
  cameraProblem,
  apiError,
}

/// Coordinates camera access, manual/live scans, and freshness results.
class ScanController extends ChangeNotifier with WidgetsBindingObserver {
  ScanController({CameraService? cameraService, ApiClient? apiClient})
    : _cameraService = cameraService ?? CameraService(),
      _apiClient = apiClient ?? ApiClient() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const scanInterval = Duration(seconds: 2);

  final CameraService _cameraService;
  final ApiClient _apiClient;
  final List<FreshnessResult> _recentLiveResults = [];
  Timer? _liveTimer;
  ScanState _state = ScanState.initializingCamera;
  CameraProblem? _cameraProblem;
  FreshnessResult? _result;
  Uint8List? _capturedFrame;
  bool _liveMode = false;
  bool _requestInFlight = false;
  bool _disposed = false;
  bool _needsCameraRestore = false;
  int _requestId = 0;

  /// Current scan state.
  ScanState get state => _state;

  /// Current camera controller for the live preview.
  CameraController? get cameraController => _cameraService.controller;

  /// Number of device cameras discovered by the service.
  int get cameraCount => _cameraService.cameraCount;

  /// Current mapped camera issue, if initialization or capture failed.
  CameraProblem? get cameraProblem => _cameraProblem;

  /// Most recent freshness result.
  FreshnessResult? get result => _result;

  /// Last captured frame, retained for a frozen result thumbnail.
  Uint8List? get capturedFrame => _capturedFrame;

  /// Whether a scan request is currently being handled.
  bool get isScanning => _state == ScanState.scanning;

  /// Whether the periodic live scan is enabled.
  bool get liveMode => _liveMode;

  /// Whether the camera switch control should be shown.
  bool get canSwitchCamera => cameraCount > 1;

  /// Start camera discovery and show a friendly mapped error on failure.
  Future<void> initialize() async {
    if (_disposed) return;
    _state = ScanState.initializingCamera;
    _cameraProblem = null;
    _needsCameraRestore = false;
    _notify();
    try {
      await _cameraService.initialize();
      if (_disposed) return;
      _state = ScanState.ready;
    } on CameraServiceException catch (error) {
      if (_disposed) return;
      _cameraProblem = error.problem;
      _state = ScanState.cameraProblem;
    } catch (_) {
      if (_disposed) return;
      _cameraProblem = CameraProblem.unknown;
      _state = ScanState.cameraProblem;
    }
    _notify();
  }

  /// Retry camera initialization after permissions or device state changes.
  Future<void> retryCamera() => initialize();

  /// Capture and classify a single frame from the current camera.
  Future<void> scan() => _scanFrame(
    live: _liveMode,
    capture: _cameraService.capture,
    requiresCamera: true,
  );

  /// Switch to the next available camera and reinitialize its preview.
  Future<void> switchCamera() async {
    if (_disposed || !canSwitchCamera || _requestInFlight) return;
    _state = ScanState.initializingCamera;
    _notify();
    try {
      await _cameraService.switchCamera();
      if (_disposed) return;
      _state = _result == null ? ScanState.ready : ScanState.result;
    } on CameraServiceException catch (error) {
      if (_disposed) return;
      _stopLiveMode();
      _cameraProblem = error.problem;
      _state = ScanState.cameraProblem;
    } catch (_) {
      if (_disposed) return;
      _stopLiveMode();
      _cameraProblem = CameraProblem.unknown;
      _state = ScanState.cameraProblem;
    }
    _notify();
  }

  /// Enable periodic scanning or stop it and discard any stale live response.
  void setLiveMode(bool enabled) {
    if (_disposed || enabled == _liveMode) return;
    if (enabled && !_cameraService.isInitialized) return;
    _liveMode = enabled;
    _liveTimer?.cancel();
    _liveTimer = null;
    if (enabled) {
      _recentLiveResults.clear();
      _liveTimer = Timer.periodic(scanInterval, (_) {
        unawaited(
          _scanFrame(
            live: true,
            capture: _cameraService.capture,
            requiresCamera: true,
          ),
        );
      });
      unawaited(
        _scanFrame(
          live: true,
          capture: _cameraService.capture,
          requiresCamera: true,
        ),
      );
    } else if (_requestInFlight) {
      _invalidateRequest();
      _state = _result == null ? ScanState.ready : ScanState.result;
    }
    _notify();
  }

  /// Pick one image as a secondary option when camera access is unavailable.
  Future<void> usePhotoInstead() async {
    if (_disposed || _requestInFlight) return;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || _disposed) return;
      await _scanFrame(
        live: false,
        capture: () async => file,
        requiresCamera: false,
      );
    } catch (_) {
      if (_disposed) return;
      _stopLiveMode();
      _state = ScanState.apiError;
      _notify();
    }
  }

  Future<void> _scanFrame({
    required bool live,
    required Future<XFile> Function() capture,
    required bool requiresCamera,
  }) async {
    if (_disposed || _requestInFlight) return;
    if (requiresCamera && !_cameraService.isInitialized) return;
    _requestInFlight = true;
    final requestId = ++_requestId;
    _state = ScanState.scanning;
    _notify();
    try {
      final frame = await capture();
      final bytes = await frame.readAsBytes();
      if (!_isCurrent(requestId)) return;
      final apiPrediction = await _apiClient.predict(bytes, frame.name);
      if (!_isCurrent(requestId)) return;
      var result = FreshnessResult.fromPrediction(apiPrediction);
      if (live) {
        _recentLiveResults.add(result);
        if (_recentLiveResults.length > 3) _recentLiveResults.removeAt(0);
        result = _averageRecentResults();
      } else {
        _recentLiveResults.clear();
      }
      _capturedFrame = bytes;
      _result = result;
      _cameraProblem = null;
      _state = ScanState.result;
    } on CameraServiceException catch (error) {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _cameraProblem = error.problem;
      _state = ScanState.cameraProblem;
    } on ApiException {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _state = ScanState.apiError;
    } catch (_) {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _state = ScanState.apiError;
    } finally {
      if (_isCurrent(requestId)) {
        _requestInFlight = false;
        _notify();
      }
    }
  }

  FreshnessResult _averageRecentResults() {
    final average = <Freshness, double>{};
    for (final freshness in Freshness.values) {
      average[freshness] =
          _recentLiveResults
              .map((result) => result.probabilities[freshness] ?? 0)
              .fold<double>(0, (sum, value) => sum + value) /
          _recentLiveResults.length;
    }
    return FreshnessResult.fromGroupedProbabilities(average);
  }

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  void _stopLiveMode() {
    _liveMode = false;
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  void _invalidateRequest() {
    _requestId++;
    _requestInFlight = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_needsCameraRestore) unawaited(initialize());
      return;
    }
    _stopLiveMode();
    _invalidateRequest();
    _needsCameraRestore =
        cameraController != null || _state != ScanState.cameraProblem;
    if (_needsCameraRestore) {
      _state = ScanState.initializingCamera;
      unawaited(_cameraService.dispose());
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLiveMode();
    _invalidateRequest();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraService.dispose());
    super.dispose();
  }
}
