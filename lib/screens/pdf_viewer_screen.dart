import 'dart:async';
import 'package:universal_io/io.dart';
import 'dart:ui' as ui;

import 'package:clipboard/clipboard.dart';
import 'package:croppy/croppy.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Provides XFile
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../tutor_client/chat_screen.dart';

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
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _checkAndCloseContextMenu();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  void _checkAndCloseContextMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  void _showContextMenu(
      BuildContext context, PdfTextSelectionChangedDetails details) {
    
    // Remove existing if any (e.g. while dragging)
    _checkAndCloseContextMenu();
    
    final OverlayState overlayState = Overlay.of(context);
    
    // Calculate position (guard against null region)
    if (details.globalSelectedRegion == null) return;
    
    final double top = details.globalSelectedRegion!.top - 60;
    final double left = details.globalSelectedRegion!.left;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: top < 0 ? 20 : top, // Ensure it sits below status bar at least
        left: left < 0 ? 0 : left, 
        child: Material(
          color: Colors.transparent,
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final selectedText = details.selectedText;
                    if (selectedText != null) {
                      Clipboard.setData(ClipboardData(text: selectedText));
                      _checkAndCloseContextMenu();
                      _pdfViewerController.clearSelection();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                  label: const Text(
                    'Copy',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                // Separation
                Container(width: 1, height: 20, color: Colors.white24),
                // "Explain" Button
                TextButton.icon(
                  onPressed: () {
                    final selectedText = details.selectedText;
                    if (selectedText != null) {
                      _checkAndCloseContextMenu();
                      _pdfViewerController.clearSelection();
                      
                      // Navigate to AI Chat with the text
                       Provider.of<NavigationProvider>(context, listen: false).navigateToChat(
                        message: "Please explain this text:\n\n\"$selectedText\"",
                        context: context, 
                      );
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, color: Colors.white, size: 14),
                  label: const Text(
                    'Explain',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Sharing $fileName',
        ),
      );
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

  /// --- 5. AI DIALOG ---
  
  void _openAiTutorDialog() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('AI Tutor'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: const ChatScreen(),
        ),
      ),
    );
  }

  /// --- 6. UI BUILD ---

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
          // --- NEW: ZOOM CONTROLS ---
          if (!_isLoading && _pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom Out',
              onPressed: () {
                final newZoom = _pdfViewerController.zoomLevel - 0.25;
                if (newZoom >= 1.0) {
                  _pdfViewerController.zoomLevel = newZoom;
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom In',
              onPressed: () {
                final newZoom = _pdfViewerController.zoomLevel + 0.25;
                if (newZoom <= 50.0) {
                  _pdfViewerController.zoomLevel = newZoom;
                }
              },
            ),
          ],

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
      floatingActionButton: !_isLoading && _pdfBytes != null
          ? FloatingActionButton.extended(
              onPressed: _openAiTutorDialog,
              backgroundColor: Theme.of(context).primaryColor,
              icon: const FaIcon(
                FontAwesomeIcons.wandMagicSparkles,
                size: 20,
              ),
              label: const Text(
                'Ask AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
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

    // --- MODIFIED: Centering & Max Width ---
    return Center(
      child: ConstrainedBox(
        // Keeps PDF comfortable to read on wide screens (Web/Tablet)
        constraints: const BoxConstraints(maxWidth: 850), 
        child: RepaintBoundary(
          key: _pdfRepaintKey,
          child: SfPdfViewer.memory(
            _pdfBytes!,
            controller: _pdfViewerController,
            canShowPaginationDialog: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
              if (details.selectedText == null && _overlayEntry != null) {
                _checkAndCloseContextMenu();
              } else if (details.selectedText != null) {
                _showContextMenu(context, details);
              }
            },
          ),
        ),
      ),
    );
  }
}