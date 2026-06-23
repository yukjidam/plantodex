import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Compresses a captured image to ~1280px long edge at 80% JPEG quality.
/// Returns the compressed [File], or the original if compression fails.
/// The same compressed file is reused across all API calls (confirm / identify / info).
class ImageCompressService {
  static const int _maxLongEdge = 1280;
  static const int _quality = 80;

  static Future<File> compressCapture(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        'plantodex_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        format: CompressFormat.jpeg,
        quality: _quality,
        minWidth: _maxLongEdge,
        minHeight: _maxLongEdge,
        keepExif: false,
      );

      if (result == null) {
        debugPrint('[ImageCompress] Compression returned null, using original');
        return File(sourcePath);
      }

      final originalSize = await File(sourcePath).length();
      final compressedSize = await result.length();
      debugPrint(
        '[ImageCompress] ${_kb(originalSize)} KB → ${_kb(compressedSize)} KB '
        '(${(compressedSize / originalSize * 100).toStringAsFixed(0)}%)',
      );

      return File(result.path);
    } catch (e) {
      debugPrint('[ImageCompress] Error: $e — using original');
      return File(sourcePath);
    }
  }

  static String _kb(int bytes) => (bytes / 1024).toStringAsFixed(0);
}
