import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// On-device "is this even a plant?" check using ML Kit Image Labeling.
/// Runs before any network call, so junk photos never burn Pl@ntNet quota.
///
/// Intentionally broad — if the image contains a flower, leaf, or branch,
/// it passes through and lets Pl@ntNet make the final call.
class PlantGateService {
  PlantGateService({double confidenceThreshold = 0.5})
      : _labeler = ImageLabeler(
          options:
              ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
        );

  final ImageLabeler _labeler;

  static const _plantKeywords = {
    'flower',
    'leaf',
    'branch',
  };

  /// Returns true if the image contains a flower, leaf, or branch.
  /// Pl@ntNet handles everything beyond that.
  Future<bool> looksLikePlant(File image) async {
    final input = InputImage.fromFile(image);
    final labels = await _labeler.processImage(input);
    return labels.any(
      (l) => _plantKeywords.contains(l.label.toLowerCase()),
    );
  }

  void dispose() {
    _labeler.close();
  }
}
