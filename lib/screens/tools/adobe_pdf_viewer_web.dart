import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

@JS('AdobeDC.View')
extension type AdobeDCView._(JSObject _) implements JSObject {
  external AdobeDCView(JSObject config);
  external JSPromise previewFile(JSObject fileConfig, JSObject viewerConfig);
}

enum EmbedMode {
  fullWindow('FULL_WINDOW'),
  sizedContainer('SIZED_CONTAINER'),
  inLine('IN_LINE'),
  lightBox('LIGHT_BOX');

  final String value;
  const EmbedMode(this.value);
}

class AdobePdfViewerWeb extends StatefulWidget {
  final String url;
  final String fileName;
  final String clientId;
  final EmbedMode embedMode;
  final bool showAnnotationTools;
  final bool showDownloadPDF;
  final bool showPrintPDF;
  final bool showLeftHandPanel;
  final VoidCallback? onLoad;
  final Function(String)? onError;

  const AdobePdfViewerWeb({
    super.key,
    required this.url,
    required this.fileName,
    required this.clientId,
    this.embedMode = EmbedMode.fullWindow,
    this.showAnnotationTools = true,
    this.showDownloadPDF = true,
    this.showPrintPDF = true,
    this.showLeftHandPanel = true,
    this.onLoad,
    this.onError,
  });

  @override
  State<AdobePdfViewerWeb> createState() => _AdobePdfViewerWebState();
}

class _AdobePdfViewerWebState extends State<AdobePdfViewerWeb> {
  late final String _viewId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'adobe-pdf-viewer-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _initAdobeViewer();
      }
    });
  }

  void _registerViewFactory() {
    // Check if already registered to avoid errors on hot reload
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final element = web.document.createElement('div');
        element.id = _viewId;
        (element as web.HTMLElement).style
          ..width = '100%'
          ..height = '100%'
          ..overflow = 'hidden';
        return element;
      });
    } catch (e) {
      debugPrint('View factory already registered or error: $e');
    }
  }

  Future<void> _initAdobeViewer() async {
    if (!_isAdobeSDKLoaded()) {
      _setError('Adobe DC View SDK not loaded. Please include the script in your index.html');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_isDisposed) return;

    try {
      final config = _jsify({
        'clientId': widget.clientId,
        'divId': _viewId,
      });

      final adobeDCView = AdobeDCView(config);

      final fileConfig = _jsify({
        'content': {
          'location': {'url': widget.url}
        },
        'metaData': {'fileName': widget.fileName}
      });

      final viewerConfig = _jsify({
        'embedMode': widget.embedMode.value,
        'showAnnotationTools': widget.showAnnotationTools,
        'showDownloadPDF': widget.showDownloadPDF,
        'showPrintPDF': widget.showPrintPDF,
        'showLeftHandPanel': widget.showLeftHandPanel,
      });

      final promise = adobeDCView.previewFile(fileConfig, viewerConfig);
      
      promise.toDart.then((_) {
        if (!_isDisposed) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
          widget.onLoad?.call();
        }
      }).catchError((error) {
        if (!_isDisposed) {
          final errorMsg = 'Failed to load PDF: ${error.toString()}';
          _setError(errorMsg);
        }
      });
    } catch (e) {
      _setError('Error initializing Adobe PDF Viewer: $e');
    }
  }

  bool _isAdobeSDKLoaded() {
    return globalContext.has('AdobeDC');
  }

  JSObject _jsify(Map<String, dynamic> map) {
    final obj = JSObject();
    for (final key in map.keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        obj.setProperty(key.toJS, _jsify(value));
      } else if (value is String) {
        obj.setProperty(key.toJS, value.toJS);
      } else if (value is bool) {
        obj.setProperty(key.toJS, value.toJS);
      } else if (value is int) {
        obj.setProperty(key.toJS, value.toJS);
      } else if (value is double) {
        obj.setProperty(key.toJS, value.toJS);
      }
    }
    return obj;
  }

  void _setError(String message) {
    debugPrint(message);
    if (!_isDisposed) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      widget.onError?.call(message);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewId),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        if (_errorMessage != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading PDF',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Example usage widget
class AdobePdfViewerExample extends StatelessWidget {
  const AdobePdfViewerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adobe PDF Viewer'),
      ),
      body: AdobePdfViewerWeb(
        url: 'https://documentservices.adobe.com/view-sdk-demo/PDFs/Bodea%20Brochure.pdf',
        fileName: 'Sample.pdf',
        clientId: 'YOUR_CLIENT_ID_HERE', // Replace with your actual client ID
        embedMode: EmbedMode.fullWindow,
        showAnnotationTools: true,
        showDownloadPDF: true,
        showPrintPDF: true,
        onLoad: () {
          debugPrint('PDF loaded successfully');
        },
        onError: (error) {
          debugPrint('Error loading PDF: $error');
        },
      ),
    );
  }
}