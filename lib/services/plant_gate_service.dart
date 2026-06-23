import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// On-device "is this even a plant?" check using ML Kit Image Labeling.
/// Runs before any network call, so junk photos never burn Pl@ntNet quota.
class PlantGateService {
  PlantGateService({double confidenceThreshold = 0.6})
      : _labeler = ImageLabeler(
          options:
              ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
        );

  final ImageLabeler _labeler;

  // ML Kit's default labeler returns generic labels from its ~400-class set.
  // These are the ones that reliably show up for plant photos.
  static const _plantKeywords = {
    'plant',
    'flower',
    'flowerpot',
    'houseplant',
    'leaf',
    'tree',
    'flowering plant',
    'botany',
    'herb',
    'shrub',
    'flora',
    'petal',
    'wildflower',
    'succulent',
  };

  /// Returns true if the image looks like it contains a plant.
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
