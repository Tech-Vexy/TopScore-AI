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
          // Prevent default behavior to handle it manually
          event.preventDefault();

          final reader = web.FileReader();
          reader.readAsDataURL(blob);
          reader.onloadend = (web.Event e) {
            if (reader.result != null) {
              // Convert JSString to Dart String
              // readAsDataURL returns a string result
              final result = (reader.result as JSString).toDart;
              onImagePasted(result);
            }
          }.toJS;

          // Stop after finding the first image
          return;
        }
      }
    }
  }.toJS;

  web.window.addEventListener('paste', _listener);
}

void removePasteHandlerImpl() {
  if (_listener != null) {
    web.window.removeEventListener('paste', _listener);
    _listener = null;
  }
}
