import 'dart:io';
import 'dart:ui' show Rect, Size;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Crops a captured photo down to whatever the user saw inside the
/// on-screen viewfinder box.
class ImageCropService {
  static Future<File> cropToViewfinder({
    required File source,
    required Rect viewfinderRect,
    required Size previewDisplaySize,
    bool isFrontCamera = false,
  }) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode captured image');
    }

    // Bake EXIF orientation first so that decoded.width/height and the
    // pixel layout both match what the user sees on screen.
    final oriented = img.bakeOrientation(decoded);

    final int imgW = oriented.width;
    final int imgH = oriented.height;

    // Express the viewfinder box as fractions of the cover-scaled preview.
    double fracLeft = viewfinderRect.left / previewDisplaySize.width;
    double fracTop = viewfinderRect.top / previewDisplaySize.height;
    double fracW = viewfinderRect.width / previewDisplaySize.width;
    double fracH = viewfinderRect.height / previewDisplaySize.height;

    // Front camera preview is mirrored on screen but the saved file is not.
    if (isFrontCamera) {
      fracLeft = 1.0 - fracLeft - fracW;
    }

    // Map fractions onto the oriented image's pixel coordinates.
    int cropX = (fracLeft * imgW).round();
    int cropY = (fracTop * imgH).round();
    int cropW = (fracW * imgW).round();
    int cropH = (fracH * imgH).round();

    // Clamp defensively.
    cropX = cropX.clamp(0, imgW - 1);
    cropY = cropY.clamp(0, imgH - 1);
    cropW = cropW.clamp(1, imgW - cropX);
    cropH = cropH.clamp(1, imgH - cropY);

    debugPrint(
        '[Crop] previewW=${previewDisplaySize.width} previewH=${previewDisplaySize.height}');
    debugPrint('[Crop] vfRect=$viewfinderRect');
    debugPrint('[Crop] imgW=$imgW imgH=$imgH');
    debugPrint(
        '[Crop] fracLeft=$fracLeft fracTop=$fracTop fracW=$fracW fracH=$fracH');
    debugPrint('[Crop] cropX=$cropX cropY=$cropY cropW=$cropW cropH=$cropH');

    final cropped = img.copyCrop(
      oriented,
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
