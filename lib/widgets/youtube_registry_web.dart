import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerYouTubeViewFactory(String viewId, String videoId) {
  // Register the iframe for web
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1&rel=0&modestbranding=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
      return iframe;
    },
  );
}
