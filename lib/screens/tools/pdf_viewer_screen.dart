import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:nutrient_flutter/nutrient_flutter.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'smart_scanner_screen.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../constants/colors.dart';

class PdfViewerScreen extends StatefulWidget {
  final String? url;
  final String? assetPath;
  final File? file;
  final Uint8List? bytes;
  final String title;

  const PdfViewerScreen({
    super.key,
    this.url,
    this.assetPath,
    this.file,
    this.bytes,
    required this.title,
  }) : assert(
         url != null || assetPath != null || file != null || bytes != null,
         'One source must be provided',
       );

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  String? _localPath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      String? path;

      if (kIsWeb) {
        if (widget.bytes != null) {
          final blob = web.Blob([widget.bytes!.toJS].toJS);
          path = web.URL.createObjectURL(blob);
        } else if (widget.url != null) {
          path = widget.url;
        } else if (widget.assetPath != null) {
          // For web, assets are served from the root
          path = 'assets/${widget.assetPath}';
        }
      } else {
        if (widget.file != null) {
          path = widget.file!.path;
        } else if (widget.assetPath != null) {
          final byteData = await rootBundle.load(widget.assetPath!);
          final file = await _createTempFile(
            byteData.buffer.asUint8List(),
            'asset_doc.pdf',
          );
          path = file.path;
        } else if (widget.bytes != null) {
          final file = await _createTempFile(widget.bytes!, 'memory_doc.pdf');
          path = file.path;
        } else if (widget.url != null) {
          final response = await http.get(Uri.parse(widget.url!));
          if (response.statusCode == 200) {
            final file = await _createTempFile(
              response.bodyBytes,
              'downloaded_doc.pdf',
            );
            path = file.path;
          } else {
            throw Exception('Failed to download PDF');
          }
        }
      }

      if (mounted) {
        setState(() {
          _localPath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<File> _createTempFile(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _captureAndScan() async {
    try {
      final image = await _screenshotController.capture();
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartScannerScreen(initialImage: image),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing screen: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Text(
            'Error: $_errorMessage',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: 'Smart Scan Page',
            onPressed: _captureAndScan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndScan,
        backgroundColor: AppColors.primary,
        tooltip: 'Smart Scan Page',
        child: const Icon(
          Icons.center_focus_strong_rounded,
          color: Colors.white,
        ),
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: NutrientView(
          documentPath: _localPath!,
          configuration: PdfConfiguration(
            enableAnnotationEditing: true,
            enableTextSelection: true,
          ),
        ),
      ),
    );
  }
}
