import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

Future<void> copyImageToClipboardImpl(Uint8List imageBytes) async {
  try {
    // Save to temp file first (required by pasteboard on some platforms)
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes(imageBytes);

    // Copy using file path for better compatibility
    await Pasteboard.writeFiles([tempFile.path]);

    // Clean up temp file after a delay
    Future.delayed(const Duration(seconds: 5), () {
      tempFile.delete().catchError((_) => tempFile);
    });
  } catch (e) {
    debugPrint("Clipboard writeFiles error: $e");
    // Fallback: Try writeImage directly with bytes
    try {
      await Pasteboard.writeImage(imageBytes);
    } catch (fallbackError) {
      debugPrint("Fallback clipboard writeImage error: $fallbackError");
      rethrow; // Let the caller handle the error
    }
  }
}
