/// Camera / gallery capture for entity photos (Spec 009 §2.2.4).
///
/// Wraps `image_picker` and the camera runtime permission behind one call.
/// Gallery picks go through the Android Photo Picker, which needs no storage
/// permission; the camera path requests `CAMERA` at first use and reports a
/// permanent denial so the screen can offer a jump to system settings.
///
/// `image_picker`'s `maxWidth` / `maxHeight` bound the longest side to 1600 px
/// on pick (keeping aspect ratio); the authoritative JPEG quality-85 re-encode
/// happens in [PhotoStorage.compressToJpeg] on the returned file.
library;

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum PhotoSource { camera, gallery }

enum CaptureStatus { captured, cancelled, denied, permanentlyDenied, error }

class CaptureResult {
  const CaptureResult(this.status, [this.filePath]);

  final CaptureStatus status;
  final String? filePath;
}

Future<CaptureResult> capturePhoto(PhotoSource source) async {
  if (source == PhotoSource.camera) {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const CaptureResult(CaptureStatus.permanentlyDenied);
    }
    if (!status.isGranted) {
      return const CaptureResult(CaptureStatus.denied);
    }
  }

  try {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return const CaptureResult(CaptureStatus.cancelled);
    return CaptureResult(CaptureStatus.captured, file.path);
  } catch (_) {
    return const CaptureResult(CaptureStatus.error);
  }
}
