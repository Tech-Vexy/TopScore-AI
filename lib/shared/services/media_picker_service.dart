import 'dart:convert';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:universal_io/io.dart';

/// Result from media picking operations
class MediaPickResult {
  final String? base64Data;
  final String? dataUri;
  final String? extension;
  final String? filePath;

  MediaPickResult({
    this.base64Data,
    this.dataUri,
    this.extension,
    this.filePath,
  });
}

/// Shared media picker service for images and files
/// Extracted from duplicate implementations in chat screens
class MediaPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<MediaPickResult?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final extension = pickedFile.path.split('.').last;
        final dataUri = 'data:image/$extension;base64,$base64Image';

        return MediaPickResult(
          base64Data: base64Image,
          dataUri: dataUri,
          extension: extension,
          filePath: pickedFile.path,
        );
      }
    } catch (e) {
      developer.log('Error picking image: $e', name: 'MediaPickerService', level: 900);
    }
    return null;
  }

  Future<MediaPickResult?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: true, // Important for Web
      );

      if (result != null) {
        String? base64Data;
        String? extension = result.files.single.extension;

        if (kIsWeb) {
          // On Web, use bytes directly
          if (result.files.single.bytes != null) {
            base64Data = base64Encode(result.files.single.bytes!);
          }
        } else {
          // On Mobile/Desktop, read from path
          if (result.files.single.path != null) {
            File file = File(result.files.single.path!);
            final bytes = await file.readAsBytes();
            base64Data = base64Encode(bytes);
          }
        }

        if (base64Data != null && extension != null) {
          final dataUri = 'data:image/$extension;base64,$base64Data';

          return MediaPickResult(
            base64Data: base64Data,
            dataUri: dataUri,
            extension: extension,
            filePath: result.files.single.path,
          );
        }
      }
    } catch (e) {
      developer.log('Error picking file: $e', name: 'MediaPickerService', level: 900);
    }
    return null;
  }
}
