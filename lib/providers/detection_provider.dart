import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/plant_identification.dart'; // PlantIdNoMatchException
import '../repositories/plant_repository.dart'; // PlantResult, NotAPlantException
import '../services/plantnet_service.dart'; // PlantNetQuotaExceededException

enum DetectionStatus {
  idle,
  identifying, // Pl@ntNet call in flight
  fetchingInfo, // Perenual call in flight
  success,
  notAPlant,
  noMatch,
  quotaExceeded,
  error,
}

class DetectionProvider extends ChangeNotifier {
  DetectionProvider({PlantRepository? repository})
      : _repository = repository ?? PlantRepository();

  final PlantRepository _repository;

  DetectionStatus status = DetectionStatus.idle;
  PlantResult? result;
  String? errorMessage;

  Future<void> identify(File photo) async {
    status = DetectionStatus.identifying;
    errorMessage = null;
    result = null;
    notifyListeners();

    try {
      final r = await _repository.identify(photo);

      status = DetectionStatus.fetchingInfo;
      notifyListeners();

      result = r;
      status = DetectionStatus.success;
    } on NotAPlantException {
      status = DetectionStatus.notAPlant;
    } on PlantIdNoMatchException {
      status = DetectionStatus.noMatch;
    } on PlantNetQuotaExceededException {
      status = DetectionStatus.quotaExceeded;
    } catch (e) {
      status = DetectionStatus.error;
      errorMessage = e.toString();
    }

    notifyListeners();
  }

  void reset() {
    status = DetectionStatus.idle;
    result = null;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
