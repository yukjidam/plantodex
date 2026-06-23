import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Reason codes returned when an image fails quality checks.
enum ImageQualityFailReason {
  tooDark,
  tooBlurry,
  tooFarAway,
}

/// Thrown by [PlantImageQualityService] when the photo isn't good enough
/// to send to Pl@ntNet. Contains a [reason] so the UI can show a specific tip.
class PoorImageQualityException implements Exception {
  const PoorImageQualityException(this.reason);
  final ImageQualityFailReason reason;

  String get userMessage {
    switch (reason) {
      case ImageQualityFailReason.tooDark:
        return 'The photo is too dark. Move to a brighter spot or turn on your flashlight.';
      case ImageQualityFailReason.tooBlurry:
        return 'The photo is blurry. Hold your phone steady and tap the plant to focus before scanning.';
      case ImageQualityFailReason.tooFarAway:
        return 'Too far away. Move closer so the plant fills most of the frame.';
    }
  }

  @override
  String toString() => 'PoorImageQualityException: $userMessage';
}

/// On-device image quality gate. Runs after [PlantGateService] confirms
/// there's a plant, but before the Pl@ntNet network call.
///
/// Checks (in order):
///   1. Brightness  — rejects images that are too dark
///   2. Blur        — rejects images using a Laplacian variance score
///   3. Coverage    — rejects images where the frame is empty / featureless
///      (plain sky, wall, floor) using edge-energy rather than green-pixel
///      counting, so bark, flowers, and other non-green organs are accepted.
class PlantImageQualityService {
  const PlantImageQualityService({
    this.minBrightness = 25.0, // 0–255 average luminance
    this.minBlurScore = 40.0, // Laplacian variance; lower = blurrier
    this.minEdgeEnergy = 4.0, // mean absolute Laplacian in centre crop
  });

  final double minBrightness;
  final double minBlurScore;
  // CHANGED: replaced minCoverage (green-pixel fraction) with minEdgeEnergy
  // (texture density). The old check rejected valid close-up crops of bark,
  // flowers, and brown/dry stems because they contain very few green pixels.
  // Edge energy stays high for any plant organ that fills the frame.
  final double minEdgeEnergy;

  /// Throws [PoorImageQualityException] if the image fails any check.
  /// Returns normally if quality is acceptable.
  Future<void> validate(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return; // can't decode → let PlantNet try anyway

    // Work on a small thumbnail for speed (300px wide).
    final thumb = img.copyResize(original, width: 300);

    _checkBrightness(thumb);
    _checkBlur(thumb);
    _checkCoverage(thumb);
  }

  // ── Brightness ─────────────────────────────────────────────────────────────

  void _checkBrightness(img.Image image) {
    double total = 0;
    final pixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        // Perceived luminance formula
        total += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    final avgLuminance = total / pixels;
    if (avgLuminance < minBrightness) {
      throw const PoorImageQualityException(ImageQualityFailReason.tooDark);
    }
  }

  // ── Blur (Laplacian variance) ───────────────────────────────────────────────

  void _checkBlur(img.Image image) {
    final grey = img.grayscale(image);
    final w = grey.width;
    final h = grey.height;

    // Laplacian kernel: [0,1,0,1,-4,1,0,1,0]
    final List<double> laplacian = [];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final center = grey.getPixel(x, y).r.toDouble();
        final top = grey.getPixel(x, y - 1).r.toDouble();
        final bottom = grey.getPixel(x, y + 1).r.toDouble();
        final left = grey.getPixel(x - 1, y).r.toDouble();
        final right = grey.getPixel(x + 1, y).r.toDouble();

        laplacian.add(top + bottom + left + right - 4 * center);
      }
    }

    // Variance of Laplacian
    final mean = laplacian.reduce((a, b) => a + b) / laplacian.length;
    final variance =
        laplacian.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            laplacian.length;

    if (variance < minBlurScore) {
      throw const PoorImageQualityException(ImageQualityFailReason.tooBlurry);
    }
  }

  // ── Coverage (plant fills the frame) ───────────────────────────────────────

  void _checkCoverage(img.Image image) {
    // Crop the centre 60 % of the image and measure edge energy (mean
    // absolute Laplacian). A frame filled with a plant organ — regardless
    // of colour — will have high texture and therefore high edge energy.
    // A blank background (plain sky, white wall, empty floor) will score
    // near zero and is correctly rejected.
    //
    // FIX: the previous implementation counted green-dominant pixels, which
    // caused every close-up crop of bark, flowers, seeds, or dry stems to
    // be rejected with tooFarAway even though the plant filled the frame.
    final cx = (image.width * 0.2).round();
    final cy = (image.height * 0.2).round();
    final cw = (image.width * 0.6).round();
    final ch = (image.height * 0.6).round();

    final crop = img.copyCrop(image, x: cx, y: cy, width: cw, height: ch);
    final grey = img.grayscale(crop);

    double edgeSum = 0;
    int count = 0;

    for (int y = 1; y < grey.height - 1; y++) {
      for (int x = 1; x < grey.width - 1; x++) {
        final center = grey.getPixel(x, y).r.toDouble();
        final top = grey.getPixel(x, y - 1).r.toDouble();
        final bottom = grey.getPixel(x, y + 1).r.toDouble();
        final left = grey.getPixel(x - 1, y).r.toDouble();
        final right = grey.getPixel(x + 1, y).r.toDouble();
        edgeSum += (4 * center - top - bottom - left - right).abs();
        count++;
      }
    }

    if (count > 0 && (edgeSum / count) < minEdgeEnergy) {
      throw const PoorImageQualityException(ImageQualityFailReason.tooFarAway);
    }
  }
}
