import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> copyImageToClipboardImpl(Uint8List imageBytes) async {
  final blob = web.Blob(
    [imageBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );

  final clipboardItem = web.ClipboardItem(
    {'image/png': blob}.jsify() as JSObject,
  );

  await web.window.navigator.clipboard.write([clipboardItem].toJS).toDart;
}
