import 'dart:js_interop';
import 'package:web/web.dart' as web;

web.EventListener? _listener;

void registerPasteHandlerImpl(Function(String dataUri) onImagePasted) {
  // If a listener already exists, remove it first to avoid duplicates
  removePasteHandlerImpl();

  _listener = (web.Event event) {
    final clipboardEvent = event as web.ClipboardEvent;

    final clipboardData = clipboardEvent.clipboardData;
    if (clipboardData == null) return;

    final items = clipboardData.items;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // Check if the item is an image
      if (item.type.startsWith('image/')) {
        final blob = item.getAsFile();
        if (blob != null) {
          // Prevent default to avoid browser trying to paste image as binary string/file path
          event.preventDefault();

          final reader = web.FileReader();
          reader.readAsDataURL(blob);
          reader.onloadend = (web.Event e) {
            final result = reader.result;
            if (result != null) {
              // Safe cast using JS interop
              final dataUri = (result as JSString).toDart;
              onImagePasted(dataUri);
            }
          }.toJS;

          break; // Only handle the first image
        }
      }
    }

    // If no image was handled, let naturally fall through to browser's default text paste
    // (unless we were explicitly called from a keyboard shortcut that already handled text)
  }.toJS;

  web.window.addEventListener('paste', _listener);
}

void removePasteHandlerImpl() {
  if (_listener != null) {
    web.window.removeEventListener('paste', _listener);
    _listener = null;
  }
}
