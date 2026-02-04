import 'dart:typed_data';

import 'clipboard_helper_non_web.dart'
    if (dart.library.js_interop) 'clipboard_helper_web.dart';

/// Copies the given [imageBytes] (expected to be PNG) to the system clipboard.
Future<void> copyImageToClipboard(Uint8List imageBytes) =>
    copyImageToClipboardImpl(imageBytes);
