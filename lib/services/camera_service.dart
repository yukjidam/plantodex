import 'dart:io';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'image_compress_service.dart';

/// Wraps Flutter's camera plugin.
/// Call [init] once, [dispose] when done, [capture] to take a photo.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _activeCameraIndex = 0;
  bool _isStreamingImages = false;

  CameraController? get controller => _controller;
  bool get isInitialised => _controller?.value.isInitialized ?? false;
  bool get isStreamingImages => _isStreamingImages;

  /// Resolution actually being captured by the sensor right now, in pixels.
  /// This is what crop math should map against — NOT the screen size.
  Size? get previewSize => _controller?.value.previewSize;

  /// True when the currently active camera is front-facing — needed by
  /// crop logic since CameraPreview mirrors the front camera for display
  /// only, while the saved capture file is unmirrored.
  bool get isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_activeCameraIndex].lensDirection == CameraLensDirection.front;

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty)
      throw CameraException('no_cameras', 'No cameras found on device');
    await _startController(_activeCameraIndex);
  }

  Future<void> _startController(int index) async {
    await _controller?.dispose();
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.high, // 1080p — enough for plant ID
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    // Lock exposure/focus to auto
    await _controller!.setFocusMode(FocusMode.auto);
    await _controller!.setExposureMode(ExposureMode.auto);
  }

  // ── Flip camera ───────────────────────────────────────────────────────────

  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;
    final wasStreaming = _isStreamingImages;
    if (wasStreaming) await stopImageStream();
    _activeCameraIndex = (_activeCameraIndex + 1) % _cameras.length;
    await _startController(_activeCameraIndex);
  }

  // ── Flash ─────────────────────────────────────────────────────────────────

  Future<FlashMode> toggleFlash() async {
    final current = _controller?.value.flashMode ?? FlashMode.off;
    final next = current == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller?.setFlashMode(next);
    return next;
  }

  // ── Live image stream (for real-time quality analysis) ─────────────────────

  /// Starts streaming raw frames to [onFrame] for real-time analysis
  /// (e.g. brightness/sharpness checks for the "good shot" pill).
  /// No-op if already streaming.
  Future<void> startImageStream(void Function(CameraImage) onFrame) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreamingImages) return;
    await _controller!.startImageStream(onFrame);
    _isStreamingImages = true;
  }

  Future<void> stopImageStream() async {
    if (_controller == null || !_isStreamingImages) return;
    await _controller!.stopImageStream();
    _isStreamingImages = false;
  }

  // ── Capture + compress ────────────────────────────────────────────────────

  /// Takes a photo and returns a compressed [File] ready for API upload.
  Future<File> capture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw CameraException('not_initialised', 'Camera not ready');
    }
    if (_controller!.value.isTakingPicture) {
      throw CameraException('already_capturing', 'Capture already in progress');
    }

    // The image stream and takePicture() compete for the same sensor on
    // most platforms — pause analysis while we actually capture. Restarting
    // the stream afterwards is the caller's responsibility (the screen
    // decides when it needs live analysis again).
    if (_isStreamingImages) await stopImageStream();

    final xfile = await _controller!.takePicture();
    debugPrint('[Camera] Raw capture saved to: ${xfile.path}');

    final compressed = await ImageCompressService.compressCapture(xfile.path);
    return compressed;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> pause() async {
    if (_controller?.value.isInitialized == true) {
      await stopImageStream();
      await _controller!.pausePreview();
    }
  }

  Future<void> resume() async {
    if (_controller?.value.isInitialized == true) {
      await _controller!.resumePreview();
    }
  }

  Future<void> dispose() async {
    _isStreamingImages = false;
    await _controller?.dispose();
    _controller = null;
  }
}
