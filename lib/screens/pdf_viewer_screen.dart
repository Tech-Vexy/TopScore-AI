import 'dart:async';
import 'package:universal_io/io.dart';
import 'dart:ui' as ui;

import 'package:clipboard/clipboard.dart';
import 'package:croppy/croppy.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Provides XFile
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String? storagePath; // Firebase path OR full URL
  final String? url; // Web URL
  final String? assetPath; // Local Asset
  final Uint8List? bytes; // Raw Data
  final File? file; // Local File
  final String title;

  const PdfViewerScreen({
    super.key,
    this.storagePath,
    this.url,
    this.assetPath,
    this.bytes,
    this.file,
    required this.title,
  }) : assert(
         storagePath != null ||
             url != null ||
             assetPath != null ||
             bytes != null ||
             file != null,
         'You must provide at least one PDF source',
       );

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey _pdfRepaintKey = GlobalKey(); // Key for screenshot capture

  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubscriptionError = false;

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  /// --- 1. SMART LOADING LOGIC ---
  Future<void> _loadPdfData() async {
    try {
      Uint8List? loadedBytes;

      if (widget.bytes != null) {
        loadedBytes = widget.bytes;
      } else if (widget.url != null) {
        loadedBytes = await _downloadFromUrl(widget.url!);
      } else if (widget.storagePath != null) {
        if (widget.storagePath!.startsWith('http')) {
          loadedBytes = await _downloadFromUrl(widget.storagePath!);
        } else {
          try {
            loadedBytes = await FirebaseStorage.instance
                .ref(widget.storagePath!)
                .getData(30 * 1024 * 1024); // 30MB limit

            if (loadedBytes == null) throw Exception("File is empty");
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
              if (mounted) {
                setState(() {
                  _isSubscriptionError = true;
                  _isLoading = false;
                });
              }
              return;
            }
            rethrow;
          }
        }
      } else if (widget.assetPath != null) {
        final byteData = await rootBundle.load(widget.assetPath!);
        loadedBytes = byteData.buffer.asUint8List();
      } else if (widget.file != null) {
        loadedBytes = await widget.file!.readAsBytes();
      }

      if (mounted) {
        setState(() {
          _pdfBytes = loadedBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading PDF: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _downloadFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("Failed to download: ${response.statusCode}");
    }
  }

  /// --- 2. DOWNLOAD FILE FEATURE ---
  Future<void> _downloadFile() async {
    if (_pdfBytes == null) return;

    try {
      // 1. Get Temp Directory (Only works on Mobile)
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download not supported on Web yet')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      final fileName = safeTitle.endsWith('.pdf')
          ? safeTitle
          : '$safeTitle.pdf';
      final file = File('${tempDir.path}/$fileName');

      // 2. Write Bytes
      await file.writeAsBytes(_pdfBytes!);

      // 3. Share/Save using native sheet
      await Share.shareXFiles([XFile(file.path)], text: 'Sharing $fileName');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  /// --- 3. CAPTURE & ACTIONS ---

  Future<Uint8List?> _captureVisibleArea() async {
    try {
      final boundary =
          _pdfRepaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<void> _captureAndAction() async {
    final fullBytes = await _captureVisibleArea();

    if (!mounted) return;
    if (fullBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture current view')),
      );
      return;
    }

    final cropResult = await showMaterialImageCropper(
      context,
      imageProvider: MemoryImage(fullBytes),
    );

    if (cropResult == null || !mounted) return;

    final croppedImage = cropResult.uiImage;
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final croppedBytes = byteData?.buffer.asUint8List();

    if (croppedBytes == null || !mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Screenshot Action",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blueGrey),
              title: const Text('Copy to Clipboard'),
              subtitle: const Text('Paste it into notes or other apps'),
              onTap: () async {
                Navigator.pop(ctx);
                await FlutterClipboard.copyImage(croppedBytes);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                }
              },
            ),
            ListTile(
              leading: const FaIcon(
                FontAwesomeIcons.wandMagicSparkles,
                color: Colors.purple,
              ),
              title: const Text('Ask AI Tutor'),
              subtitle: const Text('Get an explanation or solution instantly'),
              onTap: () async {
                Navigator.pop(ctx);
                _sendToAI(croppedBytes); // FIXED CALL
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// --- 4. FIXED: AI SENDING LOGIC (Web Compatible) ---
  Future<void> _sendToAI(Uint8List imageBytes) async {
    try {
      XFile xFile;

      if (kIsWeb) {
        // ✅ Web Fix: Use memory XFile directly (No path_provider)
        xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'screenshot.png',
        );
      } else {
        // ✅ Mobile: Use path_provider
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(imageBytes);
        xFile = XFile(file.path);
      }

      // Use NavigationProvider to switch tabs and pass data
      if (!mounted) return;

      Provider.of<NavigationProvider>(context, listen: false).navigateToChat(
        image: xFile,
        message: "Help me understand this section.",
        context: context, // Pass context to pop the viewer
      );
    } catch (e) {
      debugPrint("AI Send Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending to AI: $e')));
      }
    }
  }

  /// --- 5. UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          // Download Button
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download PDF',
              onPressed: _downloadFile,
            ),

          // Crop/AI Button
          if (!_isLoading && _pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.crop),
              tooltip: 'Capture & Ask AI',
              onPressed: _captureAndAction,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isSubscriptionError) {
      return const Center(
        child: Text(
          "🔒 Premium Content - Please Subscribe",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (_errorMessage != null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Error: $_errorMessage",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: theme.colorScheme.error,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: Text("No PDF Data"));
    }

    return RepaintBoundary(
      key: _pdfRepaintKey,
      child: SfPdfViewer.memory(
        _pdfBytes!,
        controller: _pdfViewerController,
        canShowPaginationDialog: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
      ),
    );
  }
}
