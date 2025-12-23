import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class OCRService {
  static final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static Future<String?> extractTextFromPath(String path) async {
    if (!Platform.isAndroid && !Platform.isIOS)
      return null; // ML Kit is mobile only

    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text.trim().isEmpty ? null : recognizedText.text;
    } catch (e) {
      debugPrint('OCR Error: $e');
      return null;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
