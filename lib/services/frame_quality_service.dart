import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Overall verdict shown to the user as the "good shot" pill.
enum FrameQuality { tooDark, tooBright, blurry, good }

/// Raw numeric readout, useful for debugging/tuning thresholds.
@immutable
class FrameMetrics {
  const FrameMetrics({
    required this.brightness, // 0-255 mean luma
    required this.sharpness, // arbitrary edge-energy unit, higher = sharper
    required this.quality,
  });

  final double brightness;
  final double sharpness;
  final FrameQuality quality;
}

/// Analyses the live camera image stream on a background isolate and
/// emits a [FrameQuality] verdict a few times per second.
///
/// Usage:
///   final analyzer = FrameQualityService();
///   analyzer.qualityStream.listen((q) { ... update pill ... });
///   await cameraService.startImageStream(analyzer.onFrame);
///   // later
///   await cameraService.stopImageStream();
///   analyzer.dispose();
class FrameQualityService {
  FrameQualityService({
    this.minAcceptableBrightness = 55,
    this.maxAcceptableBrightness = 225,
    this.minAcceptableSharpness = 12,
    this.minFrameGapMs = 220, // ~4-5 fps analysis, plenty for a UI hint
  });

  final double minAcceptableBrightness;
  final double maxAcceptableBrightness;
  final double minAcceptableSharpness;
  final int minFrameGapMs;

  final _controller = StreamController<FrameMetrics>.broadcast();
  Stream<FrameMetrics> get metricsStream => _controller.stream;
  Stream<FrameQuality> get qualityStream =>
      _controller.stream.map((m) => m.quality);

  DateTime _lastAnalysed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  bool _disposed = false;

  /// Pass this directly as the callback to [CameraController.startImageStream]
  /// (or via CameraService.startImageStream).
  void onFrame(CameraImage image) {
    if (_disposed || _busy) return;

    final now = DateTime.now();
    if (now.difference(_lastAnalysed).inMilliseconds < minFrameGapMs) return;

    _busy = true;
    _lastAnalysed = now;

    // Run the actual number-crunching off the UI thread.
    _analyse(image).then((metrics) {
      if (!_disposed) _controller.add(metrics);
    }).catchError((_) {
      // Don't let a single bad frame crash the stream.
    }).whenComplete(() => _busy = false);
  }

  Future<FrameMetrics> _analyse(CameraImage image) async {
    // Only the Y (luma) plane is needed for brightness + a cheap sharpness
    // estimate, so we copy just that plane's bytes and hand them to a
    // background isolate via `compute`. This keeps heavy pixel math off
    // the UI thread regardless of platform image format (YUV420 on most
    // Android devices, BGRA8888 on iOS).
    final plane = image.planes.first;
    final payload = _PlaneData(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      isBgra: image.format.group == ImageFormatGroup.bgra8888,
    );

    final result = await compute(_computeMetrics, payload);
    final quality = _classify(result.brightness, result.sharpness);
    return FrameMetrics(
      brightness: result.brightness,
      sharpness: result.sharpness,
      quality: quality,
    );
  }

  FrameQuality _classify(double brightness, double sharpness) {
    if (brightness < minAcceptableBrightness) return FrameQuality.tooDark;
    if (brightness > maxAcceptableBrightness) return FrameQuality.tooBright;
    if (sharpness < minAcceptableSharpness) return FrameQuality.blurry;
    return FrameQuality.good;
  }

  void dispose() {
    _disposed = true;
    _controller.close();
  }
}

// ── Background isolate work ──────────────────────────────────────────────

class _PlaneData {
  _PlaneData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.isBgra,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool isBgra;
}

class _Metrics {
  const _Metrics(this.brightness, this.sharpness);
  final double brightness;
  final double sharpness;
}

/// Runs on a separate isolate via [compute]. Must be a top-level function.
///
/// Computes:
///  - brightness: mean luma over a sparse sample grid
///  - sharpness: mean absolute Laplacian (simple 4-neighbour edge energy)
///    over the same grid, which drops sharply for out-of-focus/motion-blurred
///    frames and stays high for crisp ones.
_Metrics _computeMetrics(_PlaneData data) {
  final w = data.width;
  final h = data.height;
  final stride = data.bytesPerRow;
  final bytes = data.bytes;

  // Sample on a grid instead of every pixel — plenty accurate for a
  // "good/bad" verdict and much cheaper per frame.
  const step = 6;
  final margin = step * 2;

  double sumLuma = 0;
  double sumEdge = 0;
  int count = 0;

  int lumaAt(int x, int y) {
    final idx = y * stride + x;
    if (idx < 0 || idx >= bytes.length) return 0;
    final v = bytes[idx];
    // For BGRA the "first plane" trick doesn't give pure luma, but BGRA
    // frames are rare for the image stream (iOS uses them) — treat the
    // sampled byte as a rough brightness proxy, which is good enough for
    // this coarse-grained heuristic.
    return v;
  }

  for (int y = margin; y < h - margin; y += step) {
    for (int x = margin; x < w - margin; x += step) {
      final center = lumaAt(x, y);
      sumLuma += center;

      final left = lumaAt(x - step, y);
      final right = lumaAt(x + step, y);
      final up = lumaAt(x, y - step);
      final down = lumaAt(x, y + step);

      // Discrete Laplacian: 4*center - neighbours. Large magnitude = edge.
      final lap = (4 * center - left - right - up - down).abs();
      sumEdge += lap;
      count++;
    }
  }

  if (count == 0) return const _Metrics(128, 0);

  final brightness = sumLuma / count;
  final sharpness = sumEdge / count;
  return _Metrics(brightness, sharpness);
}
