import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionStatus { granted, denied, permanentlyDenied }

class PermissionService {
  /// Requests camera permission and returns the resulting status.
  static Future<CameraPermissionStatus> requestCamera() async {
    final status = await Permission.camera.request();

    if (status.isGranted) return CameraPermissionStatus.granted;
    if (status.isPermanentlyDenied)
      return CameraPermissionStatus.permanentlyDenied;
    return CameraPermissionStatus.denied;
  }

  /// Checks current permission without prompting.
  static Future<CameraPermissionStatus> checkCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return CameraPermissionStatus.granted;
    if (status.isPermanentlyDenied)
      return CameraPermissionStatus.permanentlyDenied;
    return CameraPermissionStatus.denied;
  }

  /// Opens the device app settings so the user can manually grant permission.
  static Future<void> openSettings() => openAppSettings();
}
