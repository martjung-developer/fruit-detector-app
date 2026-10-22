import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Friendly camera failure categories used by the scan UI.
enum CameraProblem { permissionDenied, noCameraFound, cameraBusy, unknown }

/// A camera failure mapped to a safe, user-facing category.
class CameraServiceException implements Exception {
  const CameraServiceException(this.problem);

  final CameraProblem problem;
}

/// Owns camera discovery, initialization, capture, switching, and disposal.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  /// Current preview controller, when a camera has been selected.
  CameraController? get controller => _controller;

  /// Number of discovered device cameras.
  int get cameraCount => _cameras.length;

  /// Whether the selected camera preview is ready to display.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Discover and initialize the default or preferred rear camera.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw const CameraServiceException(CameraProblem.noCameraFound);
      }
      _selectedCameraIndex = kIsWeb
          ? 0
          : _cameras.indexWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
            );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;
      await _initializeSelectedCamera();
    } catch (error) {
      if (error is CameraServiceException) rethrow;
      throw CameraServiceException(_mapProblem(error));
    }
  }

  /// Switch to the next available camera.
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    try {
      await _initializeSelectedCamera();
    } catch (error) {
      throw CameraServiceException(_mapProblem(error));
    }
  }

  /// Capture a single JPEG frame from the initialized camera.
  Future<XFile> capture() async {
    final current = _controller;
    if (current == null || !current.value.isInitialized) {
      throw const CameraServiceException(CameraProblem.noCameraFound);
    }
    try {
      return await current.takePicture();
    } catch (error) {
      throw CameraServiceException(_mapProblem(error));
    }
  }

  /// Pause playback while the page is backgrounded without releasing the camera.
  Future<void> pausePreview() async {
    final current = _controller;
    if (current == null ||
        !current.value.isInitialized ||
        current.value.isPreviewPaused) {
      return;
    }
    try {
      await current.pausePreview();
    } catch (error) {
      throw CameraServiceException(_mapProblem(error));
    }
  }

  /// Resume the existing preview controller when the page returns.
  Future<void> resumePreview() async {
    final current = _controller;
    if (current == null || !current.value.isInitialized) {
      throw const CameraServiceException(CameraProblem.noCameraFound);
    }
    if (!current.value.isPreviewPaused) return;
    try {
      await current.resumePreview();
    } catch (error) {
      throw CameraServiceException(_mapProblem(error));
    }
  }

  /// Release the active camera and preview resources.
  Future<void> dispose() async {
    final current = _controller;
    _controller = null;
    try {
      await current?.dispose();
    } catch (_) {
      // The device may already have released its camera during app shutdown.
    }
  }

  Future<void> _initializeSelectedCamera() async {
    await dispose();
    final cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = cameraController;
    try {
      await cameraController.initialize();
    } catch (_) {
      _controller = null;
      await cameraController.dispose();
      rethrow;
    }
  }

  CameraProblem _mapProblem(Object error) {
    final code = switch (error) {
      CameraException(:final code) => code.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };
    if (code.contains('denied') ||
        code.contains('permission') ||
        code.contains('restricted')) {
      return CameraProblem.permissionDenied;
    }
    if (code.contains('busy') ||
        code.contains('in_use') ||
        code.contains('in use')) {
      return CameraProblem.cameraBusy;
    }
    if (code.contains('notfound') ||
        code.contains('not_found') ||
        code.contains('no camera')) {
      return CameraProblem.noCameraFound;
    }
    return CameraProblem.unknown;
  }
}
