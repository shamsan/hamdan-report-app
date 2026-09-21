import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class CameraService {
  static const MethodChannel _channel = MethodChannel('com.reportcraft/camera');

  /// Launches the native camera directly and returns the captured image bytes.
  static Future<Uint8List?> capturePhotoFromCamera() async {
    try {
      final path = await _channel.invokeMethod<String>('takePhoto');
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          // Clean up temp file
          try {
            await file.delete();
          } catch (_) {}
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('[CameraService] Error taking photo: $e');
    }
    return null;
  }

  /// Opens the gallery to pick an image file and returns its bytes.
  static Future<Uint8List?> pickImageFromGallery() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        return res.files.first.bytes;
      }
    } catch (e) {
      debugPrint('[CameraService] Error picking from gallery: $e');
    }
    return null;
  }
}
