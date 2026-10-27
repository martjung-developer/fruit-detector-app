import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models/freshness_result.dart';
import '../models/scan_history.dart';
import '../services/camera_service.dart';

enum ScanState {
  initializingCamera,
  ready,
  scanning,
  result,
  cameraProblem,
  apiError,
}

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
  final ScanHistory _history = ScanHistory();
  Timer? _liveTimer;
  ScanState _state = ScanState.initializingCamera;
  CameraProblem? _cameraProblem;
  FreshnessResult? _result;
  bool _liveMode = false;
  bool _requestInFlight = false;
  bool _disposed = false;
  bool _previewPaused = false;
  bool _shouldPausePreview = false;
  Future<void> _previewTransition = Future<void>.value();
  bool _hasManualScan = false;
  int _requestId = 0;
  String? _errorMessage;
  ScanHistoryEntry? _selectedHistoryEntry;

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

  /// Whether a scan request is currently being handled.
  bool get isScanning => _requestInFlight || _state == ScanState.scanning;

  /// Whether the periodic live scan is enabled.
  bool get liveMode => _liveMode;

  /// Whether the camera switch control should be shown.
  bool get canSwitchCamera => cameraCount > 1;

  /// Saved manual scans, newest last.
  List<ScanHistoryEntry> get history => _history.entries;

  /// Whether a manual scan has been completed at least once.
  bool get hasManualScan => _hasManualScan;

  /// Friendly request or picker error for the page to display.
  String? get errorMessage => _errorMessage;

  /// Display a saved result in the right-hand result cards.
  void selectHistoryEntry(ScanHistoryEntry entry) {
    if (_disposed || !_history.entries.contains(entry)) return;
    _selectedHistoryEntry = entry;
    _result = entry.result;
    _state = ScanState.result;
    _notify();
  }

  /// Delete a saved result and return the token needed to undo it.
  DeletedScan? deleteHistoryEntry(ScanHistoryEntry entry) {
    final deleted = _history.delete(entry);
    if (deleted == null) return null;
    if (identical(_selectedHistoryEntry, entry)) {
      _selectedHistoryEntry = _history.entries.isEmpty
          ? null
          : _history.entries.last;
      _result = _selectedHistoryEntry?.result;
      if (_result == null) _state = ScanState.ready;
    }
    _notify();
    return deleted;
  }

  /// Restore a deleted result at its previous position.
  void undoDelete(DeletedScan deleted) {
    _history.undo(deleted);
    _selectedHistoryEntry = deleted.entry;
    _result = deleted.entry.result;
    _state = ScanState.result;
    _notify();
  }

  /// Clear the saved scans while leaving the currently displayed result intact.
  void clearHistory() {
    _history.clear();
    _selectedHistoryEntry = null;
    _notify();
  }

  /// Start camera discovery and show a friendly mapped error on failure.
  Future<void> initialize() async {
    if (_disposed) return;
    _state = ScanState.initializingCamera;
    _cameraProblem = null;
    _notify();
    try {
      await _cameraService.initialize();
      if (_disposed) return;
      _previewPaused = false;
      _state = ScanState.ready;
      if (_shouldPausePreview) _pausePreview();
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

  /// Pick one photo and classify it when camera access is unavailable.
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
      _errorMessage = 'Could not open the photo library. Please try again.';
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
    _errorMessage = null;
    final requestId = ++_requestId;
    _state = ScanState.scanning;
    _notify();
    try {
      final frame = await capture();
      final bytes = await frame.readAsBytes();
      if (!_isCurrent(requestId)) return;
      final apiPrediction = await _apiClient.predict(bytes, frame.name);
      if (!_isCurrent(requestId)) return;
      Uint8List? thumbnail;
      if (!live) {
        thumbnail = await _makeThumbnail(bytes);
        if (!_isCurrent(requestId)) return;
      }
      var result = FreshnessResult.fromPrediction(apiPrediction);
      if (live) {
        _recentLiveResults.add(result);
        if (_recentLiveResults.length > 3) _recentLiveResults.removeAt(0);
        result = _averageRecentResults();
      } else {
        _recentLiveResults.clear();
      }
      _result = result;
      if (requiresCamera) _cameraProblem = null;
      _state = ScanState.result;
      if (!live) {
        _hasManualScan = true;
        _selectedHistoryEntry = _history.add(
          imageBytes: thumbnail!,
          result: result,
        );
      }
    } on CameraServiceException catch (error) {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _cameraProblem = error.problem;
      _state = ScanState.cameraProblem;
    } on ApiException catch (error) {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _errorMessage = error.message;
      _state = ScanState.apiError;
    } catch (_) {
      if (!_isCurrent(requestId)) return;
      _stopLiveMode();
      _errorMessage = 'Could not classify this image. Please try again.';
      _state = ScanState.apiError;
    } finally {
      _requestInFlight = false;
      if (!_disposed) {
        if (requestId != _requestId && _state == ScanState.scanning) {
          _state = _result == null ? ScanState.ready : ScanState.result;
        }
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

  Future<Uint8List> _makeThumbnail(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
        targetHeight: 128,
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  void _stopLiveMode() {
    _liveMode = false;
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  void _invalidateRequest() {
    _requestId++;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Surface camera plugin errors even when initialization completed.
  void reportPreviewError(CameraProblem problem) {
    if (_disposed || _cameraProblem == problem) return;
    _stopLiveMode();
    _cameraProblem = problem;
    _state = ScanState.cameraProblem;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_shouldPausePreview || _previewPaused) _resumePreview();
      return;
    }
    _stopLiveMode();
    _invalidateRequest();
    _shouldPausePreview = true;
    if (_cameraService.isInitialized) _pausePreview();
    _notify();
  }

  void _pausePreview() {
    _shouldPausePreview = true;
    _previewTransition = _previewTransition.then((_) async {
      if (!_shouldPausePreview || !_cameraService.isInitialized) return;
      try {
        await _cameraService.pausePreview();
        _previewPaused = true;
      } on CameraServiceException catch (error) {
        _cameraProblem = error.problem;
        _state = ScanState.cameraProblem;
      } catch (_) {
        _cameraProblem = CameraProblem.unknown;
        _state = ScanState.cameraProblem;
      }
      _notify();
    });
  }

  void _resumePreview() {
    _shouldPausePreview = false;
    _previewTransition = _previewTransition.then((_) async {
      if (_shouldPausePreview || (!_previewPaused && _cameraProblem == null)) {
        return;
      }
      try {
        await _cameraService.resumePreview();
        _previewPaused = false;
        if (_cameraProblem != null) {
          _cameraProblem = null;
          _state = _result == null ? ScanState.ready : ScanState.result;
        }
      } on CameraServiceException catch (error) {
        _cameraProblem = error.problem;
        _state = ScanState.cameraProblem;
      } catch (_) {
        _cameraProblem = CameraProblem.unknown;
        _state = ScanState.cameraProblem;
      }
      _notify();
    });
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
