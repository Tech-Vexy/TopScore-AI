import 'package:flutter/services.dart';

import 'clipboard_helper_non_web.dart'
    if (dart.library.js_interop) 'clipboard_helper_web.dart';

/// Copies [imageBytes] (PNG) to clipboard.
Future<void> copyImageToClipboard(Uint8List imageBytes) =>
    copyImageToClipboardImpl(imageBytes);

/// Copies simple text to clipboard.
Future<void> copyTextToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
