import 'dart:js_interop';

@JS('getRecaptchaToken')
external JSPromise<JSString?> _getRecaptchaToken();

Future<String?> getRecaptchaToken() async {
  try {
    final promise = _getRecaptchaToken();
    final result = await promise.toDart;
    return result?.toDart;
  } catch (e) {
    return null;
  }
}
