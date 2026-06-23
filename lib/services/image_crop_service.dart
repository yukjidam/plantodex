import 'dart:io';
import 'dart:ui' show Rect, Size;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Crops a captured photo down to whatever the user saw inside the
/// on-screen viewfinder box.
///
/// The tricky part: the screen shows the camera preview scaled with
/// "cover" behaviour (via OverflowBox in `_CameraPreviewFill`), so the
/// edges of the sensor image are clipped off-screen. The viewfinder box's
/// position has to be converted into a *fraction of the visible preview*
/// first, and only then mapped onto the full-resolution captured image —
/// otherwise the crop drifts off target on devices whose sensor aspect
/// ratio doesn't match the screen.
class ImageCropService {
  /// [viewfinderRect] and [previewDisplaySize] must be in the same
  /// coordinate space (screen logical pixels) — i.e. exactly what was
  /// passed to `_Viewfinder` and what `_CameraPreviewFill` computed as
  /// previewW/previewH for that frame. [previewDisplaySize] is the *full*
  /// cover-scaled preview size, not the screen size (they differ whenever
  /// the sensor aspect ratio isn't an exact screen-size match).
  static Future<File> cropToViewfinder({
    required File source,
    required Rect viewfinderRect,
    required Size previewDisplaySize,
    bool isFrontCamera = false,
  }) async {
    final bytes = await source.readAsBytes();

    // decodeImage auto-applies EXIF orientation for JPEGs, so the
    // resulting `image.width/height` already match what the user expects
    // visually (no separate rotation step needed).
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode captured image');
    }

    // 1) Express the viewfinder box as a fraction (0-1) of the displayed,
    //    cover-scaled preview — this is resolution-independent.
    double fracLeft = viewfinderRect.left / previewDisplaySize.width;
    final fracTop = viewfinderRect.top / previewDisplaySize.height;
    final fracW = viewfinderRect.width / previewDisplaySize.width;
    final fracH = viewfinderRect.height / previewDisplaySize.height;

    // CameraPreview mirrors the front camera horizontally for display only
    // (so it feels like a mirror to the user) — but the saved file from
    // takePicture() is the unmirrored sensor capture. Flip the horizontal
    // fraction so the crop still lands on the same physical region of the
    // actual file, not its mirror image.
    if (isFrontCamera) {
      fracLeft = 1 - fracLeft - fracW;
    }

    // 2) Apply that same fraction to the actual decoded image. Because
    //    previewDisplaySize was itself computed with cover-scaling against
    //    the *same* sensor aspect ratio as the captured photo, fractional
    //    coordinates carry over directly — no separate aspect-ratio
    //    correction needed here.
    final imgW = decoded.width;
    final imgH = decoded.height;

    int cropX = (fracLeft * imgW).round();
    int cropY = (fracTop * imgH).round();
    int cropW = (fracW * imgW).round();
    int cropH = (fracH * imgH).round();

    // Clamp defensively — rounding or a slightly stale layout size should
    // never crash the crop.
    cropX = cropX.clamp(0, imgW - 1);
    cropY = cropY.clamp(0, imgH - 1);
    cropW = cropW.clamp(1, imgW - cropX);
    cropH = cropH.clamp(1, imgH - cropY);

    final cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final outBytes = img.encodeJpg(cropped, quality: 92);

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/crop_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(outBytes, flush: true);
    return outFile;
  }
}
