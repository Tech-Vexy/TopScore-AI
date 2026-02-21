import 'paste_handler_stub.dart'
    if (dart.library.js_interop) 'paste_handler_web.dart';

/// Registers a listener for image paste events.
///
/// [onImagePasted] is called with the base64 data URI of the pasted image.
/// This currently only works on Web.
void registerPasteHandler({required Function(String dataUri) onImagePasted}) {
  registerPasteHandlerImpl(onImagePasted);
}

/// Removes the paste listener.
void removePasteHandler() {
  removePasteHandlerImpl();
}
