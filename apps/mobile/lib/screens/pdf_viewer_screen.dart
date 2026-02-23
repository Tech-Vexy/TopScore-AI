import 'dart:async';
import 'package:universal_io/io.dart';
import 'dart:ui' as ui;

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
import 'package:pasteboard/pasteboard.dart';

import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
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
  final GlobalKey _pdfRepaintKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubscriptionError = false;
  OverlayEntry? _overlayEntry;
  bool _showSearchBar = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _checkAndCloseContextMenu();
    _searchController.dispose();
    _pdfViewerController.dispose();
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

  /// --- THEMED CONTEXT MENU ---
  void _showContextMenu(
    BuildContext context,
    PdfTextSelectionChangedDetails details,
  ) {
    _checkAndCloseContextMenu();

    final OverlayState overlayState = Overlay.of(context);
    if (details.globalSelectedRegion == null) return;

    // Theme Data extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use "Inverse Surface" for high contrast against the PDF (usually white)
    // In Light Mode: Dark Gray background. In Dark Mode: Light Gray background.
    final backgroundColor = colorScheme.inverseSurface;
    final contentColor = colorScheme.onInverseSurface;

    final double top = details.globalSelectedRegion!.top - 60;
    final double left = details.globalSelectedRegion!.left;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: top < 0 ? 20 : top,
        left: left < 0 ? 0 : left,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                ),
              ],
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
                          SnackBar(
                            content: Text(
                              'Copied to clipboard',
                              style: TextStyle(
                                color: colorScheme.onInverseSurface,
                              ),
                            ),
                            backgroundColor: colorScheme.inverseSurface,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.copy, color: contentColor, size: 16),
                  label: Text(
                    'Copy',
                    style: TextStyle(color: contentColor, fontSize: 14),
                  ),
                ),
                // Separation Divider
                Container(
                  width: 1,
                  height: 20,
                  color: contentColor.withValues(alpha: 0.3),
                ),
                // "Explain" Button
                TextButton.icon(
                  onPressed: () {
                    final selectedText = details.selectedText;
                    if (selectedText != null) {
                      _checkAndCloseContextMenu();
                      _pdfViewerController.clearSelection();

                      // Navigate to AI Chat
                      Provider.of<NavigationProvider>(
                        context,
                        listen: false,
                      ).navigateToChat(
                        message:
                            "Please explain this text:\n\n\"$selectedText\"",
                        context: context,
                      );
                    }
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    color: contentColor,
                    size: 14,
                  ),
                  label: Text(
                    'Explain',
                    style: TextStyle(color: contentColor, fontSize: 14),
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

  /// --- 1. LOADING LOGIC ---
  Future<void> _loadPdfData() async {
    try {
      final docId =
          widget.storagePath ?? widget.url ?? widget.assetPath ?? widget.title;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final canAccess = await authProvider.tryAccessDocument(docId);

      if (!canAccess) {
        if (mounted) {
          setState(() {
            _isSubscriptionError = true;
            _isLoading = false;
          });
        }
        return;
      }

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
                .getData(30 * 1024 * 1024);

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
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download not supported on Web yet')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      final fileName =
          safeTitle.endsWith('.pdf') ? safeTitle : '$safeTitle.pdf';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(_pdfBytes!);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Sharing $fileName'),
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
      final boundary = _pdfRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return null;

      // Capture at device pixel ratio for clarity
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

    // --- AUTOMATIC CLIPBOARD COPY ---
    try {
      await Pasteboard.writeImage(croppedBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Selection copied to clipboard!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 280,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Clipboard Copy Failed: $e");
    }

    // INSTANT AI TUTOR FLOW (Google Lens style)
    if (mounted) {
      _sendToAI(croppedBytes);
    }
  }

  /// --- 4. AI SENDING LOGIC ---
  Future<void> _sendToAI(Uint8List imageBytes) async {
    try {
      XFile xFile;

      if (kIsWeb) {
        xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'screenshot.png',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(imageBytes);
        xFile = XFile(file.path);
      }

      if (!mounted) return;

      // Open Chat instantly as a full-screen overlay dialog so user doesn't lose PDF context
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
            body: ChatScreen(
              initialImage: xFile,
              initialMessage: "Help me understand this section.",
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("AI Send Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending to AI: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search in document...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _pdfViewerController.searchText(value);
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _pdfViewerController.searchText(_searchController.text);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _pdfViewerController.clearSelection();
                _searchController.clear();
                setState(() => _showSearchBar = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.onInverseSurface,
                ),
                onPressed: _currentPage > 1
                    ? () => _pdfViewerController.previousPage()
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentPage / $_totalPages',
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onInverseSurface,
                ),
                onPressed: _currentPage < _totalPages
                    ? () => _pdfViewerController.nextPage()
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (!_isLoading && _pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download',
              onPressed: _downloadFile,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'zoom_in':
                    _pdfViewerController.zoomLevel += 0.25;
                    break;
                  case 'zoom_out':
                    final newZoom = _pdfViewerController.zoomLevel - 0.25;
                    if (newZoom >= 1.0) {
                      _pdfViewerController.zoomLevel = newZoom;
                    }
                    break;
                  case 'crop':
                    _captureAndAction();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'zoom_in',
                  child: Row(
                    children: [
                      Icon(Icons.zoom_in),
                      SizedBox(width: 8),
                      Text('Zoom In'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'zoom_out',
                  child: Row(
                    children: [
                      Icon(Icons.zoom_out),
                      SizedBox(width: 8),
                      Text('Zoom Out'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'crop',
                  child: Row(
                    children: [
                      Icon(Icons.crop),
                      SizedBox(width: 8),
                      Text('Capture & Ask AI'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(theme),
      // Themed Floating Action Button
      floatingActionButton: !_isLoading && _pdfBytes != null
          ? FloatingActionButton.extended(
              onPressed: _openAiTutorDialog,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 20),
              label: const Text(
                'Ask AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_isSubscriptionError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              "Premium Content",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please subscribe to access this document.",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                "Could not load PDF",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return Center(
        child: Text(
          "No PDF Data",
          style: TextStyle(color: colorScheme.onSurface),
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: RepaintBoundary(
              key: _pdfRepaintKey,
              child: SfPdfViewer.memory(
                _pdfBytes!,
                controller: _pdfViewerController,
                canShowPaginationDialog: false,
                canShowScrollStatus: false,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                onDocumentLoaded: (details) {
                  setState(() => _totalPages = details.document.pages.count);
                },
                onPageChanged: (details) {
                  setState(() => _currentPage = details.newPageNumber);
                },
                onTextSelectionChanged: (details) {
                  if (details.selectedText == null && _overlayEntry != null) {
                    _checkAndCloseContextMenu();
                  } else if (details.selectedText != null) {
                    _showContextMenu(context, details);
                  }
                },
              ),
            ),
          ),
        ),
        if (_showSearchBar) _buildSearchBar(theme),
        if (_totalPages > 0) _buildPageIndicator(theme),
      ],
    );
  }
}
