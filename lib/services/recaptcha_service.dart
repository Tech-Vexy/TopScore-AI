import 'dart:async';
import 'dart:js_interop'; // The new standard for JS
import 'dart:js_interop_unsafe'; // For checking global properties safely
import 'package:flutter/foundation.dart';

extension type GRecaptchaEnterprise._(JSObject _) implements JSObject {
  external JSPromise<JSString> execute(JSString siteKey, JSObject options);
}

@JS()
@staticInterop
class GlobalThis {}

class RecaptchaService {
  // Replace with your actual Site Key
  static const String _siteKey = "6LcgGEIsAAAAAHXWC6Wq75smJnr8fhr2VjI3eLB7";

  Future<String?> getToken(String action) async {
    // 1. Platform Check
    if (!kIsWeb) {
      debugPrint("RecaptchaService: Not running on Web.");
      return null;
    }

    try {
      // 2. Check if 'grecaptcha' exists on the global window object
      if (!globalContext.has('grecaptcha')) {
        debugPrint(
          "RecaptchaService: 'grecaptcha' script not loaded in index.html.",
        );
        return null;
      }

      // 3. Access the Enterprise object
      // Note: In strict JS interop, we cast the global property safely
      final grecaptcha = globalContext['grecaptcha'] as JSObject?;

      if (grecaptcha == null || !grecaptcha.has('enterprise')) {
        debugPrint("RecaptchaService: 'grecaptcha.enterprise' is missing.");
        return null;
      }

      final enterprise = grecaptcha['enterprise'] as GRecaptchaEnterprise;

      // 4. Prepare options: { action: 'LOGIN' }
      final options = JSObject();
      options['action'] = action.toJS;

      // 5. Execute and convert Promise to Future
      // .toDart converts the JS Promise to a Dart Future
      final JSString result = await enterprise
          .execute(_siteKey.toJS, options)
          .toDart;

      // 6. Return the raw token string
      return result.toDart;
    } catch (e) {
      debugPrint("RecaptchaService Error: $e");
      return null;
    }
  }
}
